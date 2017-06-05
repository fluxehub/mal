port module Main exposing (..)

{-| Your IDE might complain that the Json.Decode import
is not used, but it is. Without it you'll get a runtime exception.
-}

import Json.Decode
import Platform exposing (programWithFlags)
import Types exposing (MalExpr(..))
import Reader exposing (readString)
import Printer exposing (printString)
import Utils exposing (maybeToList)


{-| Output a string to stdout
-}
port output : String -> Cmd msg


{-| Read a line from the stdin
-}
port readLine : String -> Cmd msg


{-| Received a line from the stdin (in response to readLine).
-}
port input : (Maybe String -> msg) -> Sub msg


main : Program Flags Model Msg
main =
    programWithFlags
        { init = init
        , update = update
        , subscriptions = \model -> input Input
        }


type alias Flags =
    { args : List String
    }


type alias Model =
    { args : List String
    }


type Msg
    = Input (Maybe String)


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( flags, readLine prompt )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Input (Just line) ->
            let
                outputCmd =
                    rep line |> Maybe.map output

                -- Don't print output when 'rep' returns Nothing.
                cmds =
                    maybeToList outputCmd ++ [ readLine prompt ]
            in
                ( model
                , Cmd.batch cmds
                )

        Input Nothing ->
            ( model, Cmd.none )


prompt : String
prompt =
    "user> "


{-| read can return three things:

Ok (Just expr) -> parsed okay
Ok Nothing -> empty string (only whitespace and/or comments)
Err msg -> parse error

-}
read : String -> Result String (Maybe MalExpr)
read =
    readString


eval : MalExpr -> MalExpr
eval ast =
    ast


print : MalExpr -> String
print =
    printString True


{-| Read-Eval-Print
-}
rep : String -> Maybe String
rep =
    let
        formatResult result =
            case result of
                Ok optStr ->
                    optStr

                Err msg ->
                    Just msg
    in
        readString
            >> Result.map (Maybe.map (eval >> print))
            >> formatResult
