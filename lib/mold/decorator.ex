defmodule Mold.Decorator do
  @moduledoc """
  Compile-time `@parse` / `@parse!` annotations for auto-parsing function arguments.

  ## Usage

      defmodule MyModule do
        use Mold.Decorator

        @parse greet(:string, :integer)
        def greet(name, age), do: "\#{name} is \#{age}"

        @parse! process(%{name: :string})
        def process(data), do: data.name
      end

  `@parse` wraps the function to return `{:ok, result}` or `{:error, [%Mold.Error{}]}`:

      MyModule.greet("Alice", "25")
      #=> {:ok, "Alice is 25"}

      MyModule.greet("Alice", "nope")
      #=> {:error, [%Mold.Error{reason: :invalid_format, ...}]}

  `@parse!` returns the bare result or raises `Mold.Error`:

      MyModule.process(%{name: "Alice"})
      #=> "Alice"

  Arguments are parsed left-to-right. `@parse` fails fast on the first invalid
  argument (via `with`). `@parse!` raises on the first invalid argument.

  Types can reference other modules or function captures — these are
  evaluated at runtime, **not** at compile time (no compile-time dependency):

      defmodule MyApp.Stripe do
        def payment, do: %{id: :string, amount: :integer, status: {:atom, in: [:succeeded, :failed]}}
      end

      defmodule MyApp.Billing do
        use Mold.Decorator

        @parse handle_payment(MyApp.Stripe.payment())
        def handle_payment(payment), do: {:ok, payment}

        @parse! refund(&Money.parse/1, :integer)
        def refund(amount, payment_id), do: {payment_id, amount}
      end

  Use `_` to skip arguments that should be passed through without parsing:

      defmodule MyApp.UserController do
        use Mold.Decorator

        @parse create(_conn, %{name: :string, age: {:integer, min: 0}})
        def create(conn, params), do: # conn passed as-is, params parsed
      end

  ## Constraints

  - Only works with public functions (`def`), not `defp`.
  - One `@parse` or `@parse!` per function — duplicates raise `CompileError`.
  - No multi-clause support (one `@parse` per one `def`).
  """

  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [@: 1]
      import Mold.Decorator, only: [@: 1]
      Module.register_attribute(__MODULE__, :__mold_parsers__, accumulate: true)
      @before_compile Mold.Decorator
    end
  end

  defmacro @{name, _meta, [expr]} when name in [:parse, :parse!] do
    {fun_name, _meta, types} = expr
    types = types || []

    types =
      Enum.map(types, fn
        {name, _, context} when is_atom(name) and is_atom(context) ->
          if name |> Atom.to_string() |> String.starts_with?("_"),
            do: :_,
            else: {name, [], context}

        type ->
          type
      end)

    escaped = Macro.escape(types)

    quote do
      Module.put_attribute(
        __MODULE__,
        :__mold_parsers__,
        {unquote(name), unquote(fun_name), unquote(escaped)}
      )
    end
  end

  defmacro @ast do
    quote do
      Kernel.@(unquote(ast))
    end
  end

  defmacro __before_compile__(env) do
    parsers = Module.get_attribute(env.module, :__mold_parsers__) |> Enum.reverse()

    validate_no_duplicates!(parsers)

    for {mode, fun_name, types} <- parsers do
      arity = length(types)

      unless Module.defines?(env.module, {fun_name, arity}, :def) do
        raise CompileError,
          description:
            "@#{mode} #{fun_name}/#{arity} but no matching def #{fun_name}/#{arity} found"
      end

      args = Macro.generate_arguments(arity, __MODULE__)

      parse_body =
        case mode do
          :parse -> build_parse_body(types, args)
          :parse! -> build_parse_bang_body(types, args)
        end

      quote do
        defoverridable [{unquote(fun_name), unquote(arity)}]

        def unquote(fun_name)(unquote_splicing(args)) do
          unquote(parse_body)
        end
      end
    end
  end

  defp validate_no_duplicates!(parsers) do
    parsers
    |> Enum.frequencies_by(fn {_mode, fun_name, types} -> {fun_name, length(types)} end)
    |> Enum.each(fn
      {{fun_name, arity}, count} when count > 1 ->
        raise CompileError,
          description: "duplicate @parse/@parse! for #{fun_name}/#{arity}"

      _ ->
        :ok
    end)
  end

  defp build_parse_body(types, args) do
    bindings =
      types
      |> Enum.zip(args)
      |> Enum.with_index()
      |> Enum.map(fn {{type, arg}, idx} ->
        val = Macro.var(:"__mold_val_#{idx}__", __MODULE__)
        {type, arg, val}
      end)

    with_clauses =
      bindings
      |> Enum.reject(fn {type, _, _} -> type == :_ end)
      |> Enum.map(fn {type, arg, val} ->
        quote do
          {:ok, unquote(val)} <- Mold.parse(unquote(type), unquote(arg))
        end
      end)

    val_args =
      Enum.map(bindings, fn
        {:_, arg, _val} -> arg
        {_, _, val} -> val
      end)

    quote do
      with unquote_splicing(with_clauses) do
        {:ok, super(unquote_splicing(val_args))}
      end
    end
  end

  defp build_parse_bang_body(types, args) do
    parse_args =
      Enum.zip(types, args)
      |> Enum.map(fn
        {:_, arg} ->
          arg

        {type, arg} ->
          quote do
            Mold.parse!(unquote(type), unquote(arg))
          end
      end)

    quote do
      super(unquote_splicing(parse_args))
    end
  end
end
