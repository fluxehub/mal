defmodule Mix.Tasks.Step3Env do
  @initial_env %{
    "+" => &+/2,
    "-" => &-/2,
    "*" => &*/2,
    "/" => &div/2
  }

  def run(_) do
    env = Mal.Env.initialize()
    Mal.Env.merge(env, @initial_env)
    loop(env)
  end

  defp loop(env) do
    Mal.Core.readline("user> ")
      |> read_eval_print(env)
      |> IO.puts

    loop(env)
  end

  defp eval_ast(ast, env) when is_list(ast) do
    Enum.map(ast, fn elem -> eval(elem, env) end)
  end

  defp eval_ast(ast, env) when is_map(ast) do
    for {key, value} <- ast, into: %{} do
      {eval(key, env), eval(value, env)}
    end
  end

  defp eval_ast({:vector, ast}, env) do
    {:vector, Enum.map(ast, fn elem -> eval(elem, env) end)}
  end

  defp eval_ast({:symbol, symbol}, env) do
    case Mal.Env.get(env, symbol) do
      {:ok, value} -> value
      :not_found -> throw({:error, "invalid symbol #{symbol}"})
    end
  end

  defp eval_ast(ast, _env), do: ast

  defp read(input) do
    Mal.Reader.read_str(input)
  end

  defp eval_bindings({:vector, vector}, env), do: eval_bindings(vector, env)
  defp eval_bindings([], _env), do: _env
  defp eval_bindings([{:symbol, key}, binding | tail], env) do
    evaluated = eval(binding, env)
    Mal.Env.set(env, key, evaluated)
    eval_bindings(tail, env)
  end
  defp eval_bindings(_bindings, _env), do: throw({:error, "Unbalanced let* bindings"})


  defp eval([{:symbol, "def!"}, {:symbol, key}, value], env) do
    evaluated = eval(value, env)
    Mal.Env.set(env, key, evaluated)
    evaluated
  end

  defp eval([{:symbol, "let*"}, bindings, body], env) do
    let_env = Mal.Env.initialize(env)
    eval_bindings(bindings, let_env)
    eval(body, let_env)
  end

  defp eval(ast, env) when is_list(ast) do
    [func | args] = eval_ast(ast, env)
    apply(func, args)
  end

  defp eval(ast, env), do: eval_ast(ast, env)

  defp print(value) do
    Mal.Printer.print_str(value)
  end

  defp read_eval_print(:eof, _env), do: exit(:normal)
  defp read_eval_print(line, env) do
    read(line)
      |> eval(env)
      |> print
  catch
    {:error, message} -> IO.puts("Error: #{message}")
  end
end
