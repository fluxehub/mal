-- ---------------------------------------------------------
-- reader.sql

PROMPT "reader.sql start";

CREATE OR REPLACE TYPE tokens FORCE AS TABLE OF varchar2(4000);
/

CREATE OR REPLACE TYPE readerT FORCE AS OBJECT (
    position  integer,
    toks      tokens,
    MEMBER FUNCTION peek (SELF IN OUT NOCOPY readerT) RETURN varchar,
    MEMBER FUNCTION next (SELF IN OUT NOCOPY readerT) RETURN varchar
);
/


CREATE OR REPLACE TYPE BODY readerT AS
    MEMBER FUNCTION peek (SELF IN OUT NOCOPY readerT) RETURN varchar IS
    BEGIN
        IF position > toks.COUNT THEN
            RETURN NULL;
        END IF;
        RETURN toks(position);
    END;
    MEMBER FUNCTION next (SELF IN OUT NOCOPY readerT) RETURN varchar IS
    BEGIN
        position := position + 1;
        RETURN toks(position-1);
    END;
END;
/


CREATE OR REPLACE PACKAGE reader IS
    FUNCTION read_str(M IN OUT NOCOPY mem_type,
                      H IN OUT NOCOPY types.map_entry_table,
                      str varchar) RETURN integer;
END reader;
/
show errors;

CREATE OR REPLACE PACKAGE BODY reader AS

FUNCTION tokenize(str varchar) RETURN tokens IS
    re      varchar2(100) := '[[:space:] ,]*(~@|[][{}()''`~@]|"(([\].|[^\"])*)"|;[^' || chr(10) || ']*|[^][[:space:] {}()''"`~@,;]*)';
    tok     varchar2(4000);
    toks    tokens := tokens();
    cnt     integer;
BEGIN
    cnt := REGEXP_COUNT(str, re);
    FOR I IN 1..cnt LOOP
        tok := REGEXP_SUBSTR(str, re, 1, I, 'm', 1);
        IF tok IS NOT NULL AND SUBSTR(tok, 1, 1) <> ';' THEN
            toks.extend();
            toks(toks.COUNT) := tok;
            -- stream_writeline('tok: [' || tok || ']');
        END IF;
    END LOOP;
    RETURN toks;
END;

-- read_atom:
-- takes a readerT
-- updates readerT and returns value
FUNCTION read_atom(M IN OUT NOCOPY mem_type,
                   rdr IN OUT NOCOPY readerT) RETURN integer IS
    str_id  integer;
    str     varchar2(4000);
    token   varchar2(4000);
    result  integer;
BEGIN
    token := rdr.next();
    -- stream_writeline('read_atom: ' || token);
    IF token = 'nil' THEN       -- nil
        result := 1;
    ELSIF token = 'false' THEN  -- false
        result := 2;
    ELSIF token = 'true' THEN   -- true
        result := 3;
    ELSIF REGEXP_LIKE(token, '^-?[0-9][0-9]*$') THEN  -- integer
        result := types.int(M, CAST(token AS integer));
    ELSIF REGEXP_LIKE(token, '^".*"') THEN  -- string
        -- string
        str := SUBSTR(token, 2, LENGTH(token)-2);
        str := REPLACE(str, '\"', '"');
        str := REPLACE(str, '\n', chr(10));
        str := REPLACE(str, '\\', chr(92));
        result := types.string(M, str);
    ELSIF REGEXP_LIKE(token, '^:.*') THEN  -- keyword
         -- keyword
         result := types.keyword(M, SUBSTR(token, 2, LENGTH(token)-1));
    ELSE
        -- symbol
        result := types.symbol(M, token);
    END IF;
    return result;
END;

-- forward declaration of read_form
FUNCTION read_form(M IN OUT NOCOPY mem_type,
                   H IN OUT NOCOPY types.map_entry_table,
                   rdr IN OUT NOCOPY readerT) RETURN integer;

-- read_seq:
-- takes a readerT
-- updates readerT and returns new mal_list/vector/hash-map
FUNCTION read_seq(M IN OUT NOCOPY mem_type,
                  H IN OUT NOCOPY types.map_entry_table,
                  rdr IN OUT NOCOPY readerT, type_id integer,
                  first varchar, last varchar)
    RETURN integer IS
    token   varchar2(4000);
    items   mal_seq_items_type;
BEGIN
    token := rdr.next();
    IF token <> first THEN
        raise_application_error(-20003,
            'expected ''' || first || '''', TRUE);
    END IF;
    items := mal_seq_items_type();
    LOOP
        token := rdr.peek();
        IF token IS NULL THEN
            raise_application_error(-20003,
                'expected ''' || last || '''', TRUE);
        END IF;
        IF token = last THEN EXIT; END IF;
        items.EXTEND();
        items(items.COUNT) := read_form(M, H, rdr);
    END LOOP;
    token := rdr.next();
    IF type_id IN (8,9) THEN
        RETURN types.seq(M, type_id, items);
    ELSE
        RETURN types.hash_map(M, H, items);
    END IF;
END;

-- read_form:
-- takes a readerT
-- updates the readerT and returns new mal value
FUNCTION read_form(M IN OUT NOCOPY mem_type,
                   H IN OUT NOCOPY types.map_entry_table,
                   rdr IN OUT NOCOPY readerT) RETURN integer IS
    token   varchar2(4000);
    meta    integer;
    midx    integer;
BEGIN
     token := rdr.peek();  -- peek
     CASE
    WHEN token = '''' THEN
        token := rdr.next();
        RETURN types.list(M,
                          types.symbol(M, 'quote'),
                          read_form(M, H, rdr));
    WHEN token = '`' THEN
        token := rdr.next();
        RETURN types.list(M,
                          types.symbol(M, 'quasiquote'),
                          read_form(M, H, rdr));
    WHEN token = '~' THEN
        token := rdr.next();
        RETURN types.list(M,
                          types.symbol(M, 'unquote'),
                          read_form(M, H, rdr));
    WHEN token = '~@' THEN
        token := rdr.next();
        RETURN types.list(M,
                          types.symbol(M, 'splice-unquote'),
                          read_form(M, H, rdr));
    WHEN token = '^' THEN
        token := rdr.next();
        meta := read_form(M, H, rdr);
        RETURN types.list(M,
                          types.symbol(M, 'with-meta'),
                          read_form(M, H, rdr),
                              meta);
    WHEN token = '@' THEN
        token := rdr.next();
        RETURN types.list(M,
                          types.symbol(M, 'deref'),
                          read_form(M, H, rdr));

    -- list
    WHEN token = ')' THEN
        raise_application_error(-20002,
            'unexpected '')''', TRUE);
    WHEN token = '(' THEN
        RETURN read_seq(M, H, rdr, 8, '(', ')');

    -- vector
    WHEN token = ']' THEN
        raise_application_error(-20002,
            'unexpected '']''', TRUE);
    WHEN token = '[' THEN
        RETURN read_seq(M, H, rdr, 9, '[', ']');

    -- hash-map
    WHEN token = '}' THEN
        raise_application_error(-20002,
            'unexpected ''}''', TRUE);
    WHEN token = '{' THEN
        RETURN read_seq(M, H, rdr, 10, '{', '}');

    -- atom/scalar
    ELSE
        RETURN read_atom(M, rdr);
    END CASE;
END;

-- read_str:
-- takes a string
-- returns a new mal value
FUNCTION read_str(M IN OUT NOCOPY mem_type,
                  H IN OUT NOCOPY types.map_entry_table,
                  str varchar) RETURN integer IS
    toks  tokens;
    rdr   readerT;
BEGIN
    toks := tokenize(str);
    rdr := readerT(1, toks);
    -- stream_writeline('token 1: ' || rdr.peek());
    RETURN read_form(M, H, rdr);
END;

END reader;
/
show errors;

PROMPT "reader.sql finished";
