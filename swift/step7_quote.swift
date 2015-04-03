//******************************************************************************
// MAL - step 7 - quote
//******************************************************************************
// This file is automatically generated from templates/step.swift. Rather than
// editing it directly, it's probably better to edit templates/step.swift and
// regenerate this file. Otherwise, your change might be lost if/when someone
// else performs that process.
//******************************************************************************

import Foundation

// The number of times EVAL has been entered recursively. We keep track of this
// so that we can protect against overrunning the stack.
//
var EVAL_level = 0

// The maximum number of times we let EVAL recurse before throwing an exception.
// Testing puts this at some place between 1800 and 1900. Let's keep it at 500
// for safety's sake.
//
let EVAL_leval_max = 500

// Control whether or not tail-call optimization (TCO) is enabled. We want it
// `true` most of the time, but may disable it for debugging purposes (it's
// easier to get a meaningful backtrace that way).
//
let TCO = true

// Control whether or not we emit debugging statements in EVAL.
//
let DEBUG_EVAL = false

// String used to prefix information logged in EVAL. Increasing lengths of the
// string are used the more EVAL is recursed.
//
let INDENT_TEMPLATE = "|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|" +
    "----|----|----|----|----|----|----|----|----|----|----|"

// Holds the prefix of INDENT_TEMPLATE used for actual logging.
//
var indent = String()

// Symbols used in this module.
//
let kSymbolArgv             = MalSymbol(symbol: "*ARGV*")
let kSymbolConcat           = MalSymbol(symbol: "concat")
let kSymbolCons             = MalSymbol(symbol: "cons")
let kSymbolDef              = MalSymbol(symbol: "def!")
let kSymbolDo               = MalSymbol(symbol: "do")
let kSymbolEval             = MalSymbol(symbol: "eval")
let kSymbolFn               = MalSymbol(symbol: "fn*")
let kSymbolIf               = MalSymbol(symbol: "if")
let kSymbolLet              = MalSymbol(symbol: "let*")
let kSymbolQuasiQuote       = MalSymbol(symbol: "quasiquote")
let kSymbolQuote            = MalSymbol(symbol: "quote")
let kSymbolSpliceUnquote    = MalSymbol(symbol: "splice-unquote")
let kSymbolUnquote          = MalSymbol(symbol: "unquote")

// Class to help control the incrementing and decrementing of EVAL_level. We
// create one of these on entry to EVAL, incrementing the level. When the
// variable goes out of scope, the object is destroyed, decrementing the level.
//
class EVAL_Counter {
    init() {
        ++EVAL_level
    }
    deinit {
        --EVAL_level
    }
}

// Parse the string into an AST.
//
func READ(str: String) -> MalVal {
    return read_str(str)
}

// Return whether or not `val` is a non-empty list.
//
func is_pair(val:MalVal) -> Bool {
    if !is_sequence(val) { return false }
    let list = val as MalSequence
    return !list.isEmpty
}

// Evaluate `quasiquote`, possibly recursing in the process.
//
// As with quote, unquote, and splice-unquote, quasiquote takes a single
// parameter, typically a list. In the general case, this list is processed
// recursively as:
//
//  (quasiquote (first rest...)) -> (cons (quasiquote first) (quasiquote rest))
//
// In the processing of the parameter passed to it, quasiquote handles three
// special cases:
//
//  *   If the parameter is an atom or an empty list, the following expression
//      is formed and returned for evaluation:
//
//          (quasiquote atom-or-empty-list) -> (quote atom-or-empty-list)
//
//  *   If the first element of the non-empty list is the symbol "unquote"
//      followed by a second item, the second item is returned as-is:
//
//          (quasiquote (unquote fred)) -> fred
//
//  *   If the first element of the non-empty list is another list containing
//      the symbol "splice-unquote" followed by a list, that list is catenated
//      with the quasiquoted result of the remaining items in the non-empty
//      parent list:
//
//          (quasiquote (splice-unquote list) rest...) -> (items-from-list items-from-quasiquote(rest...))
//
// Note the inconsistent handling between "quote" and "splice-quote". The former
// is handled when this function is handed a list that starts with "quote",
// whereas the latter is handled when this function is handled a list whose
// first element is a list that starts with "splice-quote". The handling of the
// latter is forced by the need to incorporate the results of (splice-quote
// list) with the remaining items of the list containing that splice-quote
// expression. However, it's not clear to me why the handling of "unquote" is
// not handled similarly, for consistency's sake.

func quasiquote(qq_arg:MalVal) -> MalVal {

    // If the argument is an atom or empty list:
    //
    // Return: (quote <argument>)

    if !is_pair(qq_arg) {
        return MalList(objects: kSymbolQuote, qq_arg)
    }

    // The argument is a non-empty list -- that is (item rest...)

    // If the first item from the list is a symbol and it's "unquote" -- that
    // is, (unquote item ignored...):
    //
    // Return: item

    let qq_list = qq_arg as MalSequence
    if is_symbol(qq_list.first()) {
        let sym = qq_list.first() as MalSymbol
        if sym == kSymbolUnquote {
            return qq_list.count >= 2 ? qq_list[1] : MalNil()
        }
    }

    // If the first item from the list is itself a non-empty list starting with
    // "splice-unquote"-- that is, ((splice-unquote item ignored...) rest...):
    //
    // Return: (concat item quasiquote(rest...))

    if is_pair(qq_list.first()) {
        let qq_list_item0 = qq_list.first() as MalSequence
        if is_symbol(qq_list_item0.first()) {
            let sym = qq_list_item0.first() as MalSymbol
            if sym == kSymbolSpliceUnquote {
                let result = quasiquote(qq_list.rest())
                if is_error(result) { return result }
                return MalList(array: [kSymbolConcat, qq_list_item0[1], result])
            }
        }
    }

    // General case: (item rest...):
    //
    // Return: (cons (quasiquote item) (quasiquote (rest...))

    let first = quasiquote(qq_list.first())
    if is_error(first) { return first }

    let rest = quasiquote(qq_list.rest())
    if is_error(rest) { return rest }

    return MalList(objects: kSymbolCons, first, rest)
}

// Perform a simple evaluation of the `ast` object. If it's a symbol,
// dereference it and return its value. If it's a collection, call EVAL on all
// elements (or just the values, in the case of the hashmap). Otherwise, return
// the object unchanged.
//
func eval_ast(ast: MalVal, env: Environment) -> MalVal {
    if is_symbol(ast) {
        let symbol = ast as MalSymbol
        if let val = env.get(symbol) {
            return val
        }
        return MalError(message: "'\(symbol)' not found")    // Specific text needed to match MAL unit tests
    }
    if is_list(ast) {
        let list = ast as MalList
        var result = [MalVal]()
        result.reserveCapacity(list.count)
        for item in list {
            let eval = EVAL(item, env)
            if is_error(eval) { return eval }
            result.append(eval)
        }
        return MalList(array: result)
    }
    if is_vector(ast) {
        let vec = ast as MalVector
        var result = [MalVal]()
        result.reserveCapacity(vec.count)
        for item in vec {
            let eval = EVAL(item, env)
            if is_error(eval) { return eval }
            result.append(eval)
        }
        return MalVector(array: result)
    }
    if is_hashmap(ast) {
        let hash = ast as MalHashMap
        var result = [MalVal]()
        result.reserveCapacity(hash.count * 2)
        for (k, v) in hash {
            let new_v = EVAL(v, env)
            if is_error(new_v) { return new_v }
            result.append(k)
            result.append(new_v)
        }
        return MalHashMap(array: result)
    }
    return ast
}

enum TCOVal {
    case NoResult
    case Return(MalVal)
    case Continue(MalVal, Environment)

    init() { self = .NoResult }
    init(_ result: MalVal) { self = .Return(result) }
    init(_ ast: MalVal, _ env: Environment) { self = .Continue(ast, env) }
    init(_ e: String) { self = .Return(MalError(message: e)) }
}

// EVALuate "def!".
//
func eval_def(list: MalSequence, env: Environment) -> TCOVal {
    if list.count != 3 {
        return TCOVal("expected 2 arguments to def!, got \(list.count - 1)")
    }
    let arg1 = list[1]
    let arg2 = list[2]
    if !is_symbol(arg1) {
        return TCOVal("expected symbol for first argument to def!")
    }
    let sym = arg1 as MalSymbol
    let value = EVAL(arg2, env)
    if is_error(value) { return TCOVal(value) }
    return TCOVal(env.set(sym, value))
}

// EVALuate "let*".
//
func eval_let(list: MalSequence, env: Environment) -> TCOVal {
    if list.count != 3 {
        return TCOVal("expected 2 arguments to let*, got \(list.count - 1)")
    }
    let arg1 = list[1]
    let arg2 = list[2]
    if !is_sequence(arg1) {
        return TCOVal("expected list for first argument to let*")
    }
    let bindings = arg1 as MalSequence
    if bindings.count % 2 == 1 {
        return TCOVal("expected even number of elements in bindings to let*, got \(bindings.count)")
    }
    var new_env = Environment(outer: env)
    for var index = 0; index < bindings.count; index += 2 {
        let binding_name = bindings[index]
        let binding_value = bindings[index + 1]

        if !is_symbol(binding_name) {
            return TCOVal("expected symbol for first element in binding pair")
        }
        let binding_symbol = binding_name as MalSymbol
        let evaluated_value = EVAL(binding_value, new_env)
        if is_error(evaluated_value) { return TCOVal(evaluated_value) }
        new_env.set(binding_symbol, evaluated_value)
    }
    if TCO {
        return TCOVal(arg2, new_env)
    }
    return TCOVal(EVAL(arg2, new_env))
}

// EVALuate "do".
//
func eval_do(list: MalSequence, env: Environment) -> TCOVal {
    if TCO {
        let eval = eval_ast(MalList(slice: list[1..<list.count-1]), env)
        if is_error(eval) { return TCOVal(eval) }
        return TCOVal(list.last(), env)
    }

    let evaluated_ast = eval_ast(list.rest(), env)
    if is_error(evaluated_ast) { return TCOVal(evaluated_ast) }
    let evaluated_seq = evaluated_ast as MalSequence
    return TCOVal(evaluated_seq.last())
}

// EVALuate "if".
//
func eval_if(list: MalSequence, env: Environment) -> TCOVal {
    if list.count < 3 {
        return TCOVal("expected at least 2 arguments to if, got \(list.count - 1)")
    }
    let cond_result = EVAL(list[1], env)
    var new_ast = MalVal()
    if is_truthy(cond_result) {
        new_ast = list[2]
    } else if list.count == 4 {
        new_ast = list[3]
    } else {
        return TCOVal(MalNil())
    }
    if TCO {
        return TCOVal(new_ast, env)
    }
    return TCOVal(EVAL(new_ast, env))
}

// EVALuate "fn*".
//
func eval_fn(list: MalSequence, env: Environment) -> TCOVal {
    if list.count != 3 {
        return TCOVal("expected 2 arguments to fn*, got \(list.count - 1)")
    }
    if !is_sequence(list[1]) {
        return TCOVal("expected list or vector for first argument to fn*")
    }
    return TCOVal(MalClosure(eval: EVAL, args:list[1] as MalSequence, body:list[2], env:env))
}

// EVALuate "quote".
//
func eval_quote(list: MalSequence, env: Environment) -> TCOVal {
    if list.count >= 2 {
        return TCOVal(list[1])
    }
    return TCOVal(MalNil())
}

// EVALuate "quasiquote".
//
func eval_quasiquote(list: MalSequence, env: Environment) -> TCOVal {
    if list.count >= 2 {
        if TCO {
            return TCOVal(quasiquote(list[1]), env)
        }
        return TCOVal(EVAL(quasiquote(list[1]), env))
    }
    return TCOVal("Expected non-nil parameter to 'quasiquote'")
}

// Walk the AST and completely evaluate it, handling macro expansions, special
// forms and function calls.
//
func EVAL(var ast: MalVal, var env: Environment) -> MalVal {
    let x = EVAL_Counter()
    if EVAL_level > EVAL_leval_max {
        return MalError(message: "Recursing too many levels (> \(EVAL_leval_max))")
    }

    if DEBUG_EVAL {
        indent = prefix(INDENT_TEMPLATE, EVAL_level)
    }

    while true {
        if is_error(ast) { return ast }
        if DEBUG_EVAL { println("\(indent)>   \(ast)") }

        if !is_list(ast) {

            // Not a list -- just evaluate and return.

            let answer = eval_ast(ast, env)
            if DEBUG_EVAL { println("\(indent)>>> \(answer)") }
            return answer
        }

        // Special handling if it's a list.

        var list = ast as MalList
        if DEBUG_EVAL { println("\(indent)>.  \(list)") }

        if list.isEmpty {
            return list
        }

        // Check for special forms, where we want to check the operation
        // before evaluating all of the parameters.

        let arg0 = list.first()
        if is_symbol(arg0) {
            var res: TCOVal
            let fn_symbol = arg0 as MalSymbol

            switch fn_symbol {
                case kSymbolDef:            res = eval_def(list, env)
                case kSymbolLet:            res = eval_let(list, env)
                case kSymbolDo:             res = eval_do(list, env)
                case kSymbolIf:             res = eval_if(list, env)
                case kSymbolFn:             res = eval_fn(list, env)
                case kSymbolQuote:          res = eval_quote(list, env)
                case kSymbolQuasiQuote:     res = eval_quasiquote(list, env)
                default:                    res = TCOVal()
            }
            switch res {
                case let .Return(result):               return result
                case let .Continue(new_ast, new_env):   ast = new_ast; env = new_env; continue
                case .NoResult:                         break
            }
        }

        // Standard list to be applied. Evaluate all the elements first.

        let eval = eval_ast(ast, env)
        if is_error(eval) { return eval }

        // The result had better be a list and better be non-empty.

        let eval_list = eval as MalList
        if eval_list.isEmpty {
            return eval_list
        }

        if DEBUG_EVAL { println("\(indent)>>  \(eval)") }

        // Get the first element of the list and execute it.

        let first = eval_list.first()
        let rest = eval_list.rest()

        if is_builtin(first) {
            let fn = first as MalBuiltin
            let answer = fn.apply(rest)
            if DEBUG_EVAL { println("\(indent)>>> \(answer)") }
            return answer
        } else if is_closure(first) {
            let fn = first as MalClosure
            var new_env = Environment(outer: fn.env)
            let result = new_env.set_bindings(fn.args, with_exprs:rest)
            if is_error(result) { return result }
            if TCO {
                env = new_env
                ast = fn.body
                continue
            }
            let answer = EVAL(fn.body, new_env)
            if DEBUG_EVAL { println("\(indent)>>> \(answer)") }
            return answer
        }

        // The first element wasn't a function to be executed. Return an
        // error saying so.

        return MalError(message: "first list item does not evaluate to a function: \(first)")
    }
}

// Convert the value into a human-readable string for printing.
//
func PRINT(exp: MalVal) -> String? {
    if is_error(exp) { return nil }
    return pr_str(exp, true)
}

// Perform the READ and EVAL steps. Useful for when you don't care about the
// printable result.
//
func RE(text: String, env: Environment) -> MalVal? {
    if text.isEmpty { return nil }
    let ast = READ(text)
    if is_error(ast) {
        println("Error parsing input: \(ast)")
        return nil
    }
    let exp = EVAL(ast, env)
    if is_error(exp) {
        println("Error evaluating input: \(exp)")
        return nil
    }
    return exp
}

// Perform the full READ/EVAL/PRINT, returning a printable string.
//
func REP(text: String, env: Environment) -> String? {
    let exp = RE(text, env)
    if exp == nil { return nil }
    return PRINT(exp!)
}

// Perform the full REPL.
//
func REPL(env: Environment) {
    while true {
        if let text = _readline("user> ") {
            if let output = REP(text, env) {
                println("\(output)")
            }
        } else {
            println()
            break
        }
    }
}

// Process any command line arguments. Any trailing arguments are incorporated
// into the environment. Any argument immediately after the process name is
// taken as a script to execute. If one exists, it is executed in lieu of
// running the REPL.
//
func process_command_line(args:[String], env:Environment) -> Bool {
    var argv = MalList()
    if args.count > 2 {
        let args1 = args[2..<args.count]
        let args2 = args1.map { MalString(unescaped: $0) as MalVal }
        let args3 = [MalVal](args2)
        argv = MalList(array: args3)
    }
    env.set(kSymbolArgv, argv)

    if args.count > 1 {
        RE("(load-file \"\(args[1])\")", env)
        return false
    }

    return true
}

func main() {
    var env = Environment(outer: nil)

    load_history_file()
    load_builtins(env)

    RE("(def! not (fn* (a) (if a false true)))", env)
    RE("(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \")\")))))", env)

    env.set(kSymbolEval, MalBuiltin(function: {
         unwrap($0) {
            (ast:MalVal) -> MalVal in
            EVAL(ast, env)
         }
    }))

    if process_command_line(Process.arguments, env) {
        REPL(env)
    }

    save_history_file()
}
