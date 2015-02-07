require types.fs
require printer.fs

-2 constant skip-elem

\ Drop a char off the front of string by advancing the addr and
\ decrementing the length, and fetch next char
: adv-str ( str-addr str-len -- str-addr str-len char )
    swap 1+ swap 1-
    dup 0= if 0 ( eof )
    else over c@ endif ;

: skip-spaces ( str-addr str-len char -- str-addr str-len non-space-char )
    begin
        dup bl = if
            -1
        else
            dup [char] , =
        endif
    while ( str-addr str-len space-char )
        drop adv-str
    repeat ;

: mal-digit? ( char -- flag )
    dup [char] 9 <= if
        [char] 0 >=
    else
        drop 0
    endif ;

: char-in-str? ( char str-addr str-len )
    rot { needle }
    begin ( str-addr str-len )
        adv-str needle = if
            2drop -1 -1 \ success! drop and exit
        else
            dup 0= if
                2drop 0 -1 \ str consumed, char not found.
            else
                0 \ continue
            endif
        endif
    until ;

s\" []{}()'\"`,; " constant non-sym-chars-len constant non-sym-chars
: sym-char? ( char -- flag )
    non-sym-chars non-sym-chars-len char-in-str? 0= ;

defer read-form ( str-addr str-len -- str-addr str-len mal-obj )

: read-int ( str-addr str-len digit-char -- str-addr str-len non-digit-char mal-int )
    0 { int }
    begin ( str-addr str-len digit-char )
        [char] 0 - int 10 * + to int ( str-addr str-len )
        adv-str dup mal-digit? 0= ( str-addr str-len digit-char )
    until
    int MalInt. ;

: read-comment ( str-addr str-len sym-char -- str-addr str-len char skim-elem )
    drop
    begin
        adv-str = 10
    until
    adv-str skip-elem ;

: read-symbol-str ( str-addr str-len sym-char -- str-addr str-len char sym-addr sym-len )
    new-str { sym-addr sym-len }
    begin ( str-addr str-len sym-char )
        sym-addr sym-len rot str-append-char to sym-len to sym-addr
        adv-str dup sym-char? 0=
    until
    sym-addr sym-len ;

: read-string-literal ( in-addr in-len quote-char -- in-addr in-len mal-string )
    new-str { out-addr out-len }
    drop \ drop leading quote
    begin ( in-addr in-len )
        adv-str over 0= if
            2drop s\" expected '\"', got EOF\n" safe-type 1 throw
        endif
        dup [char] " <>
    while
        dup [char] \ = if
            drop adv-str
            dup [char] n = if drop 10 endif
            dup [char] r = if drop 13 endif
        endif
        out-addr out-len rot str-append-char to out-len to out-addr
    repeat
    drop adv-str \ skip trailing quote
    out-addr out-len MalString. ;

: read-list ( str-addr str-len open-paren-char -- str-addr str-len non-paren-char mal-list )
    \ push objects onto "dictionary" -- maybe not the best stack for this?
    0 { close-char len }
    drop adv-str
    begin ( str-addr str-len char )
        skip-spaces ( str-addr str-len non-space-char )
        over 0= if
            drop 2drop
            s\" expected '" close-char str-append-char
            s\" ', got EOF" str-append safe-type 1 throw
        endif
        dup close-char <>
    while ( str-addr str-len non-space-non-paren-char )
        read-form , len 1+ to len
    repeat
    drop adv-str

    \ pop objects out of "dictionary" into MalList
    mal-nil
    len 0 ?do
        0 cell - allot
        here @ swap conj
    loop
    ;

: read-wrapped ( buf-addr buf-len quote-char sym-addr sym-len -- buf-addr buf-len char mal-list )
    MalSymbol. { sym } ( buf-addr buf-len char )
    read-form mal-nil conj ( buf-addr buf-len char mal-list )
    sym swap conj ;

: read-form2 ( str-addr str-len char -- str-addr str-len char mal-obj )
    begin
        skip-spaces
        dup mal-digit? if read-int else
        dup [char] ( = if [char] ) read-list else
        dup [char] [ = if [char] ] read-list MalVector new tuck MalVector/list ! else
        dup [char] { = if [char] } read-list MalMap new tuck MalMap/list ! else
        dup [char] " = if read-string-literal else
        dup [char] ; = if read-comment else
        dup [char] @ = if drop adv-str s" deref" read-wrapped else
        dup [char] ' = if drop adv-str s" quote" read-wrapped else
        dup [char] ` = if drop adv-str s" quasiquote" read-wrapped else
        dup [char] ~ = if
            drop adv-str
            dup [char] @ = if drop adv-str s" splice-unquote" read-wrapped
            else s" unquote" read-wrapped
            endif
        else
        dup [char] ^ = if
            drop adv-str
            read-form { meta } read-form { obj }
            meta mal-nil conj
            obj swap conj
            s" with-meta" MalSymbol. swap conj
        else
            read-symbol-str MalSymbol.
        endif endif endif endif endif endif endif endif endif endif endif
        dup skip-elem =
    while drop repeat ;
' read-form2 is read-form

: read-str ( str-addr str-len - mal-obj )
    over c@ read-form { obj } drop 2drop obj ;
