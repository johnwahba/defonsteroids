defmodule Steroids do
  defmacro defonsteroids(definition, do: body) do
    {name, params} = Macro.decompose_call(definition)
    quote do
      def unquote(name)(unquote_splicing(params)) do
        unquote(memoize(body))
      end
    end
  end

  def memoize({:|>, meta,[arg, {func, _, func_args}]} = body) do
    memoize({func, meta, [arg | func_args]})
  end
  def memoize({op,meta,statements}) when op in [:->, :=, :<-] do
    {op, meta, Enum.map(statements, &memoize/1)}
  end
  def memoize({op,meta,statements} = body) when is_list(statements) do
    quote do
      ConCache.get_or_store(
        :steroids_cache,
        {
          Keyword.take(binding(), unquote(relevant_bindings(body))),
          unquote(function_body_to_cache_key(body) |> Macro.escape())
        } ,
        fn() -> unquote({op, meta, Enum.map(statements, &memoize/1)}) end)
    end
  end
  def memoize(body), do: body

  def function_body_to_cache_key(body) do
    Macro.prewalk(body, fn(ast) ->
      Macro.update_meta(ast, &Keyword.delete(&1, :line))
      |> Macro.update_meta(&Keyword.delete(&1, :counter))
    end)
  end

  def relevant_bindings({var, _, nil}), do: [var]
  def relevant_bindings({_, _, list}) when is_list(list) do
    list
    |> Enum.flat_map(&relevant_bindings/1)
    |> Enum.uniq
  end
  def relevant_bindings(_), do: []
end

defmodule Test do
  import Steroids

  defonsteroids fib(0), do: 0
  defonsteroids fib(1), do: 1
  defonsteroids fib(n) do
    fib(n-1) + fib(n-2)
  end
end
