module MAL.Reader

open System

#nowarn "40"

open System.Text.RegularExpressions
open Types
open State

let malRegex = Regex (@"[\s,]*(~@|[\[\]{}()'`~^@]|""(?:\\.|[^\\""])*""?|;.*|[^\s\[\]{}('""`,;)]*)", RegexOptions.Compiled)
let stringRegex = Regex (@"""(?:[\\].|[^\\""])*""", RegexOptions.Compiled)

type TokenStream = string list

let peek =
    State (fun (stream: TokenStream) -> List.head stream, stream)

let tryPeek =
    State (fun (stream: TokenStream) ->
        let result =
            match stream with
            | [] -> None
            | s  -> Some (List.head s)
        (result, stream)
    )

let next =
    State (fun (stream: TokenStream) -> List.head stream, List.tail stream)

let skip =
    State (fun (stream: TokenStream) -> (), List.tail stream)

let tokenize input: TokenStream =
    let matches = malRegex.Matches input
    // Copied-ish from the C# implementation
    matches
    |> Seq.map (fun m -> m.Groups.[1].Value)
    |> Seq.filter (fun t -> (t <> null) && not (t = "") && not (t.[0] = ';'))
    |> Seq.toList        

let unescape (string: string) =
    string
        .Replace("\\n", "\n")
        .Replace("\\\"", "\"")
        .Replace("\\\\", "\\")
        
let read_atom (token: string) =
    match Int32.TryParse token with
    | true, int -> MalNumber int
    | _ ->
        if stringRegex.IsMatch token then
            MalString <| unescape token.[1..(token.Length - 2)]
        elif token.[0] = '"' then
            failwith "\" unbalanced, expected closing \""
        else
            match token with
            | "true"  -> MalBool true
            | "false" -> MalBool false
            | "nil"   -> MalNil
            | s       -> MalSymbol s

let rec read_form =
    state {
        let! token = peek
        match token with
        // Macros
        | "'"  -> return! read_macro MacroQuote
        | "`"  -> return! read_macro MacroQuasiquote
        | "~"  -> return! read_macro MacroUnquote
        | "~@" -> return! read_macro MacroSpliceUnquote
        | "@"  -> return! read_macro MacroDeref
        
        // Lists
        | "(" ->
            do! skip
            return! read_seq MalList "(" ")"
        | "[" ->
            do! skip
            return! read_seq MalVector "[" "]"
        
        // Anything else is an atom (or invalid)
        | _  ->
            let! token = next
            return read_atom token
    }
    
and read_seq malType sOpen sClose: State<TokenStream, MalType> =
    state {
        let rec buildSeq seq =
            state {
                let! token = tryPeek
                match token with
                | Some token ->
                    if token = sClose then
                        // Clear the stream
                        do! skip
                        return seq
                    else
                        let! value = read_form
                        return! buildSeq <| Seq.append seq [value]
                | None ->
                    return failwith $"\"{sOpen}\" unbalanced, expected closing \"{sClose}\""
            }
        
        let! seq = buildSeq []
        return seq |> List.ofSeq |> malType
    }
    
and read_macro macro =
    state {
        do! skip
        let! value = read_form
        return (MalMacro <| macro value)
    }
    
let read_str input =
    let tokens = tokenize input
    if List.length tokens = 0 then
        None
    else
        let value, stream = read_form |> State.run tokens
        if List.length stream <> 0 then
            failwith "Unexpected tokens in input"
        else
            Some value