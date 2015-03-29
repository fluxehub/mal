#!/usr/bin/env julia

import reader
import printer

# READ
function READ(str)
    reader.read_str(str)
end

# EVAL
function eval_ast(ast, env)
    if typeof(ast) == Symbol
        env[ast]
    elseif isa(ast, Array)
        map((x) -> EVAL(x,env), ast)
    else
        ast
    end
end

function EVAL(ast, env)
    if !isa(ast, Array)
        return eval_ast(ast, env)
    end

    # apply
    el = eval_ast(ast, env)
    f, args = el[1], el[2:end]
    f(args...)
end

# PRINT
function PRINT(exp)
    printer.pr_str(exp)
end

# REPL
repl_env = {:+ => +,
            :- => -,
            :* => *,
            :/ => div}
function REP(str)
    return PRINT(EVAL(READ(str), repl_env))
end

while true
    print("user> ")
    flush(STDOUT)
    line = readline(STDIN)
    if line == ""
        break
    end
    line = chomp(line)
    try
        println(REP(line))
    catch e
        if isa(e, ErrorException)
            println("Error: $(e.msg)")
        else
            println("Error: $(string(e))")
        end
        bt = catch_backtrace()
        Base.show_backtrace(STDERR, bt)
        println()
    end
end
