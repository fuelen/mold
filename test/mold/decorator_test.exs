defmodule Mold.DecoratorTest.ParseModule do
  use Mold.Decorator

  @parse greet(:string, :integer)
  def greet(name, age), do: "#{name} is #{age}"
end

defmodule Mold.DecoratorTest.ParseBangModule do
  use Mold.Decorator

  @parse! process(%{name: :string})
  def process(data), do: data.name
end

defmodule Mold.DecoratorTest.MapModule do
  use Mold.Decorator

  @parse parse_user(%{name: :string, age: :integer})
  def parse_user(user), do: "#{user.name} (#{user.age})"
end

defmodule Mold.DecoratorTest.MultiModule do
  use Mold.Decorator

  @parse add(:integer, :integer)
  def add(a, b), do: a + b

  @parse! upcase(:string)
  def upcase(s), do: String.upcase(s)
end

defmodule Mold.DecoratorTest.SkipModule do
  use Mold.Decorator

  @parse handle(_, %{name: :string})
  def handle(conn, params), do: {conn, params}

  @parse! handle_bang(_conn, :integer)
  def handle_bang(conn, id), do: {conn, id}
end

defmodule Mold.DecoratorTest do
  use ExUnit.Case, async: true

  alias Mold.DecoratorTest.ParseModule
  alias Mold.DecoratorTest.ParseBangModule

  describe "@parse" do
    test "returns {:ok, result} with valid args" do
      assert {:ok, "Alice is 25"} = ParseModule.greet("Alice", 25)
    end

    test "coerces string arg to integer" do
      assert {:ok, "Alice is 25"} = ParseModule.greet("Alice", "25")
    end

    test "returns {:error, errors} with invalid arg" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} =
               ParseModule.greet("Alice", "not_a_number")
    end

    test "fails fast on first invalid arg" do
      assert {:error, [%Mold.Error{}]} = ParseModule.greet(nil, "not_a_number")
    end
  end

  describe "@parse!" do
    test "returns bare result with valid args" do
      assert "Alice" = ParseBangModule.process(%{"name" => "Alice"})
    end

    test "raises Mold.Error with invalid args" do
      assert_raise Mold.Error, fn -> ParseBangModule.process("not a map") end
    end
  end

  describe "complex types" do
    alias Mold.DecoratorTest.MapModule

    test "@parse with map type" do
      assert {:ok, "Alice (25)"} = MapModule.parse_user(%{"name" => "Alice", "age" => "25"})
    end

    test "@parse with map type returns errors" do
      assert {:error, [%Mold.Error{} | _]} = MapModule.parse_user("not a map")
    end
  end

  describe "multiple functions" do
    alias Mold.DecoratorTest.MultiModule

    test "multiple @parse and @parse! in one module" do
      assert {:ok, 3} = MultiModule.add("1", "2")
      assert "HELLO" = MultiModule.upcase("hello")
    end
  end

  describe "skip with _" do
    alias Mold.DecoratorTest.SkipModule

    test "@parse with _ passes argument through unchanged" do
      assert {:ok, {:conn, %{name: "Alice"}}} =
               SkipModule.handle(:conn, %{"name" => "Alice"})
    end

    test "@parse with _ still parses other arguments" do
      assert {:error, [%Mold.Error{}]} =
               SkipModule.handle(:conn, %{"name" => 123})
    end

    test "@parse! with _ passes argument through unchanged" do
      assert {:conn, 42} = SkipModule.handle_bang(:conn, "42")
    end
  end

  describe "standard attributes" do
    test "@doc and @moduledoc work with use Mold.Decorator" do
      defmodule WithDocs do
        use Mold.Decorator

        @moduledoc "Module doc"
        @doc "Function doc"
        @parse echo(:string)
        def echo(s), do: s
      end

      assert {:ok, "hi"} = WithDocs.echo("hi")
    end
  end

  describe "compile-time validation" do
    test "raises CompileError when type count != function arity" do
      assert_raise CompileError, fn ->
        defmodule ArityMismatch do
          use Mold.Decorator

          @parse bad(:string, :integer)
          def bad(only_one_arg), do: only_one_arg
        end
      end
    end

    test "raises CompileError when @parse has no matching def" do
      assert_raise CompileError, fn ->
        defmodule NoDef do
          use Mold.Decorator

          @parse missing(:string)
        end
      end
    end

    test "raises CompileError on duplicate @parse for the same function" do
      assert_raise CompileError, fn ->
        defmodule Duplicate do
          use Mold.Decorator

          @parse dup(:string)
          @parse dup(:string)
          def dup(s), do: s
        end
      end
    end
  end
end
