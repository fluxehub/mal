package mal

fun read(input: String?): MalType = read_str(input)

fun eval(_ast: MalType, _env: Env): MalType {
    var ast = _ast
    var env = _env

    while (true) {
        ast = macroexpand(ast, env)

        if (ast is MalList) {
            val first = ast.first()

            if (first is MalSymbol && first.value == "def!") {
                return env.set(ast.nth(1) as MalSymbol, eval(ast.nth(2), env))
            } else if (first is MalSymbol && first.value == "let*") {
                val childEnv = Env(env)
                val bindings = ast.nth(1) as? ISeq ?: throw MalException("expected sequence as the first parameter to let*")

                val it = bindings.seq().iterator()
                while (it.hasNext()) {
                    val key = it.next()
                    if (!it.hasNext()) throw MalException("odd number of binding elements in let*")
                    childEnv.set(key as MalSymbol, eval(it.next(), childEnv))
                }

                env = childEnv
                ast = ast.nth(2)
            } else if (first is MalSymbol && first.value == "fn*") {
                val binds = ast.nth(1) as? ISeq ?: throw MalException("fn* requires a binding list as first parameter")
                val params = binds.seq().filterIsInstance<MalSymbol>() // TODO error if any non-symbols?
                val body = ast.nth(2)

                return MalFnFunction(body, params, env, { s: ISeq ->
                    eval(body, Env(env, params, s.seq()))
                })
            } else if (first is MalSymbol && first.value == "do") {
                eval_ast(ast.slice(1, ast.seq().count() - 1), env)
                ast = ast.seq().last()
            } else if (first is MalSymbol && first.value == "if") {
                val check = eval(ast.nth(1), env)

                if (check != NIL && check != FALSE) {
                    ast = ast.nth(2)
                } else if (ast.seq().asSequence().count() > 3) {
                    ast = ast.nth(3)
                } else return NIL
            } else if (first is MalSymbol && first.value == "quote") {
                return ast.nth(1)
            } else if (first is MalSymbol && first.value == "quasiquote") {
                ast = quasiquote(ast.nth(1))
            } else if (first is MalSymbol && first.value == "defmacro!") {
                val macro = eval(ast.nth(2), env) as MalFunction
                macro.is_macro = true
                return env.set(ast.nth(1) as MalSymbol, macro)
            } else if (first is MalSymbol && first.value == "macroexpand") {
                return macroexpand(ast.nth(1), env)
            } else if (first is MalSymbol && first.value == "try*") {
                val body = ast.nth(1)
                try {
                    return eval(body, env)
                } catch (e: Exception) {
                    val thrown = if (e is MalException) e else MalException(e.message)
                    val symbol = (ast.nth(2) as MalList).nth(1) as MalSymbol
                    val catchBody = (ast.nth(2) as MalList).nth(2)
                    val catchEnv = Env(env)
                    catchEnv.set(symbol, thrown)
                    return eval(catchBody, catchEnv)
                }
            } else if (first is MalSymbol && first.value == "with-meta") {
                val obj = eval(ast.nth(1), env)
                val metadata = eval(ast.nth(2), env)
                return obj.with_meta(metadata)
            } else if (first is MalSymbol && first.value == "atom") {
                return MalAtom(eval(ast.nth(1), env))
            } else {
                val evaluated = eval_ast(ast, env) as ISeq
                val firstEval = evaluated.first()

                if (firstEval is MalFnFunction) {
                    ast = firstEval.ast
                    env = Env(firstEval.env, firstEval.params, evaluated.rest().seq())
                } else if (firstEval is MalFunction) {
                    return firstEval.apply(evaluated.rest())
                } else throw MalException("cannot execute non-function")
            }
        } else return eval_ast(ast, env)
    }
}

fun eval_ast(ast: MalType, env: Env): MalType =
        if (ast is MalSymbol) {
            env.get(ast)
        } else if (ast is MalList) {
            ast.elements.fold(MalList(), { a, b -> a.conj_BANG(eval(b, env)); a })
        } else if (ast is MalVector) {
            ast.elements.fold(MalVector(), { a, b -> a.conj_BANG(eval(b, env)); a })
        } else if (ast is MalHashMap) {
            ast.elements.entries.fold(MalHashMap(), { a, b -> a.assoc_BANG(b.key, eval(b.value, env)); a })
        } else ast

private fun is_pair(ast: MalType): Boolean = ast is ISeq && ast.seq().any()

private fun quasiquote(ast: MalType): MalType {
    if (!is_pair(ast)) {
        val quoted = MalList()
        quoted.conj_BANG(MalSymbol("quote"))
        quoted.conj_BANG(ast)
        return quoted
    }

    val seq = ast as ISeq
    var first = seq.first()

    if ((first as? MalSymbol)?.value == "unquote") {
        return seq.nth(1)
    }

    if (is_pair(first) && ((first as ISeq).first() as? MalSymbol)?.value == "splice-unquote") {
        val spliced = MalList()
        spliced.conj_BANG(MalSymbol("concat"))
        spliced.conj_BANG((first as ISeq).nth(1))
        spliced.conj_BANG(quasiquote(MalList(seq.seq().drop(1).toLinkedList())))
        return spliced
    }

    val consed = MalList()
    consed.conj_BANG(MalSymbol("cons"))
    consed.conj_BANG(quasiquote(ast.first()))
    consed.conj_BANG(quasiquote(MalList(seq.seq().drop(1).toLinkedList())))
    return consed
}

private fun is_macro_call(ast: MalType, env: Env): Boolean {
    val symbol = (ast as? MalList)?.first() as? MalSymbol ?: return false
    val function = env.find(symbol) as? MalFunction ?: return false
    return function.is_macro
}

private fun macroexpand(_ast: MalType, env: Env): MalType {
    var ast = _ast
    while (is_macro_call(ast, env)) {
        val symbol = (ast as MalList).first() as MalSymbol
        val function = env.find(symbol) as MalFunction
        ast = function.apply(ast.rest())
    }
    return ast
}

fun print(result: MalType) = pr_str(result, print_readably = true)

fun rep(input: String, env: Env): String =
        print(eval(read(input), env))

fun main(args: Array<String>) {
    val repl_env = Env()
    ns.forEach({ it -> repl_env.set(it.key, it.value) })

    repl_env.set(MalSymbol("*host-language*"), MalString("kotlin"))

    // Need to cast the strings explicitly to MalType to get this to compile.  Looks like a bug in kotlinc,
    // and it results in a warning.
    repl_env.set(MalSymbol("*ARGV*"), MalList(args.drop(1).map({ it -> MalString(it) as MalType }).toLinkedList()))
    repl_env.set(MalSymbol("eval"), MalFunction({ a: ISeq -> eval(a.first(), repl_env) }))

    rep("(def! not (fn* (a) (if a false true)))", repl_env)
    rep("(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \")\")))))", repl_env)
    rep("(defmacro! cond (fn* (& xs) (if (> (count xs) 0) (list 'if (first xs) (if (> (count xs) 1) (nth xs 1) (throw \"odd number of forms to cond\")) (cons 'cond (rest (rest xs)))))))", repl_env)
    rep("(defmacro! or (fn* (& xs) (if (empty? xs) nil (if (= 1 (count xs)) (first xs) `(let* (or_FIXME ~(first xs)) (if or_FIXME or_FIXME (or ~@(rest xs))))))))", repl_env)

    if (args.any()) {
        rep("(load-file \"${args[0]}\")", repl_env)
        return
    }

    while (true) {
        val input = readline("user> ")
        try {
            println(rep(input, repl_env))
        } catch (e: EofException) {
            break
        } catch (e: MalContinue) {
        } catch (e: MalException) {
            println("Error: " + e.message)
        } catch (t: Throwable) {
            println("Uncaught " + t + ": " + t.message)
            t.printStackTrace()
        }
    }
}
