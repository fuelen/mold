defmodule Mold.RecursiveFixture do
  def parse_comment(value) do
    Mold.parse(%{text: :string, replies: {[&parse_comment/1], nilable: true}}, value)
  end
end

defmodule MoldTest do
  use ExUnit.Case, async: true
  doctest Mold

  describe "parse!/2" do
    test "single error without trace" do
      assert_raise Mold.Error,
                   """
                   Unable to parse data

                   :unexpected_nil (value: nil)
                   """,
                   fn -> Mold.parse!(:string, nil) end
    end

    test "single error with trace" do
      schema = {:map, fields: [name: [type: :string, source: "name"]]}

      assert_raise Mold.Error,
                   """
                   Unable to parse data

                   :unexpected_nil at [:name] (value: nil)
                   """,
                   fn -> Mold.parse!(schema, %{"name" => nil}) end
    end

    test "multiple errors" do
      schema =
        {:map,
         fields: [
           name: [type: :string, source: "name"],
           age: [type: :integer, source: "age"]
         ]}

      assert_raise Mold.Error,
                   """
                   Unable to parse data

                   2 errors:
                     1. :unexpected_type at [:name] (value: 123)
                     2. :invalid_format at [:age] (value: "abc")
                   """,
                   fn -> Mold.parse!(schema, %{"name" => 123, "age" => "abc"}) end
    end
  end

  describe "parse/2" do
    test ":atom" do
      assert Mold.parse(:atom, :active) == {:ok, :active}
      assert Mold.parse(:atom, "active") == {:ok, :active}

      assert Mold.parse(:atom, "definitely_not_existing_atom_xyz") ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: :unknown_atom,
                    value: "definitely_not_existing_atom_xyz"
                  })
                ]}

      assert Mold.parse(:atom, 123) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: 123})]}

      assert Mold.parse(:atom, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:atom, nilable: true}, nil) == {:ok, nil}
    end

    test ":boolean" do
      assert Mold.parse(:boolean, true) == {:ok, true}
      assert Mold.parse(:boolean, false) == {:ok, false}
      assert Mold.parse(:boolean, "true") == {:ok, true}
      assert Mold.parse(:boolean, "false") == {:ok, false}
      assert Mold.parse(:boolean, "1") == {:ok, true}
      assert Mold.parse(:boolean, "0") == {:ok, false}
      assert Mold.parse(:boolean, 1) == {:ok, true}
      assert Mold.parse(:boolean, 0) == {:ok, false}

      assert Mold.parse(:boolean, "yes") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "yes"})]}

      assert Mold.parse(:boolean, 2) ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: 2})]}

      assert Mold.parse(:boolean, %{}) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: %{}})]}

      assert Mold.parse(:boolean, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:boolean, nilable: true}, nil) == {:ok, nil}

      assert Mold.parse({:boolean, nilable: false}, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:boolean, []}, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}
    end

    test ":integer" do
      assert Mold.parse(:integer, 10) == {:ok, 10}
      assert Mold.parse(:integer, "10") == {:ok, 10}

      assert Mold.parse(:integer, "10.5") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "10.5"})]}

      assert Mold.parse(:integer, "abc") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "abc"})]}

      assert Mold.parse(:integer, 10.5) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: 10.5})]}

      assert Mold.parse(:integer, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:integer, nilable: true}, nil) == {:ok, nil}
      assert Mold.parse({:integer, min: 0}, 5) == {:ok, 5}
      assert Mold.parse({:integer, min: 0}, 0) == {:ok, 0}

      assert Mold.parse({:integer, min: 0}, -1) ==
               {:error, [Mold.Error.new(%{reason: {:too_small, min: 0}, value: -1})]}

      assert Mold.parse({:integer, max: 10}, 10) == {:ok, 10}

      assert Mold.parse({:integer, max: 10}, 11) ==
               {:error, [Mold.Error.new(%{reason: {:too_large, max: 10}, value: 11})]}

      assert Mold.parse({:integer, min: 0, max: 100}, "50") == {:ok, 50}

      assert Mold.parse({:integer, min: 0, max: 100}, "-1") ==
               {:error, [Mold.Error.new(%{reason: {:too_small, min: 0}, value: -1})]}

      assert Mold.parse({:integer, min: 1}, "0") ==
               {:error, [Mold.Error.new(%{reason: {:too_small, min: 1}, value: 0})]}
    end

    test ":float" do
      assert Mold.parse(:float, 3.14) == {:ok, 3.14}
      assert Mold.parse(:float, 10) == {:ok, 10.0}
      assert Mold.parse(:float, "3.14") == {:ok, 3.14}
      assert Mold.parse(:float, "10") == {:ok, 10.0}
      assert Mold.parse(:float, "1.5e3") == {:ok, 1500.0}

      assert Mold.parse(:float, "2.14abc") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "2.14abc"})]}

      assert Mold.parse(:float, "1.5e3abc") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "1.5e3abc"})]}

      assert Mold.parse(:float, "abc") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "abc"})]}

      assert Mold.parse(:float, true) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: true})]}

      assert Mold.parse(:float, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:float, nilable: true}, nil) == {:ok, nil}

      assert Mold.parse({:float, min: 0.0}, -0.5) ==
               {:error, [Mold.Error.new(%{reason: {:too_small, min: 0.0}, value: -0.5})]}

      assert Mold.parse({:float, max: 1.0}, 1.5) ==
               {:error, [Mold.Error.new(%{reason: {:too_large, max: 1.0}, value: 1.5})]}
    end

    test ":string" do
      assert Mold.parse(:string, "hello") == {:ok, "hello"}

      assert Mold.parse(:string, "") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: ""})]}

      assert Mold.parse(:string, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      # trim is on by default
      assert Mold.parse(:string, " hello ") == {:ok, "hello"}

      assert Mold.parse(:string, "  ") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: "  "})]}

      # trim: false preserves whitespace
      assert Mold.parse({:string, trim: false}, "  ") == {:ok, "  "}
      assert Mold.parse({:string, trim: false}, " hello ") == {:ok, " hello "}

      assert Mold.parse({:string, nilable: true}, nil) == {:ok, nil}
      assert Mold.parse({:string, nilable: true}, "") == {:ok, nil}
      assert Mold.parse({:string, nilable: true}, "  ") == {:ok, nil}
      assert Mold.parse({:string, format: ~r/^\d{4}$/}, "2024") == {:ok, "2024"}

      assert inspect(Mold.parse({:string, format: ~r/^\d{4}$/}, "abcd")) ==
               inspect(
                 {:error,
                  [Mold.Error.new(%{reason: {:invalid_format, ~r/^\d{4}$/}, value: "abcd"})]}
               )

      assert Mold.parse({:string, format: ~r/@/, trim: true}, " user@example.com ") ==
               {:ok, "user@example.com"}

      assert inspect(Mold.parse({:string, format: ~r/@/, trim: true}, " nope ")) ==
               inspect(
                 {:error, [Mold.Error.new(%{reason: {:invalid_format, ~r/@/}, value: "nope"})]}
               )

      # min_length / max_length
      assert Mold.parse({:string, min_length: 3}, "abc") == {:ok, "abc"}
      assert Mold.parse({:string, min_length: 3}, "abcd") == {:ok, "abcd"}

      assert Mold.parse({:string, min_length: 3}, "ab") ==
               {:error, [Mold.Error.new(%{reason: {:too_short, min_length: 3}, value: "ab"})]}

      assert Mold.parse({:string, max_length: 5}, "hello") == {:ok, "hello"}

      assert Mold.parse({:string, max_length: 5}, "helloo") ==
               {:error, [Mold.Error.new(%{reason: {:too_long, max_length: 5}, value: "helloo"})]}

      assert Mold.parse({:string, min_length: 2, max_length: 5}, "hi") == {:ok, "hi"}
      assert Mold.parse({:string, min_length: 2, max_length: 5}, "hello") == {:ok, "hello"}

      assert Mold.parse({:string, min_length: 2, max_length: 5}, "h") ==
               {:error, [Mold.Error.new(%{reason: {:too_short, min_length: 2}, value: "h"})]}

      assert Mold.parse({:string, min_length: 2, max_length: 5}, "helloo") ==
               {:error, [Mold.Error.new(%{reason: {:too_long, max_length: 5}, value: "helloo"})]}

      # trim happens before length validation (trim is on by default)
      assert Mold.parse({:string, min_length: 3}, "  abc  ") == {:ok, "abc"}

      assert Mold.parse({:string, min_length: 5}, "  abc  ") ==
               {:error, [Mold.Error.new(%{reason: {:too_short, min_length: 5}, value: "abc"})]}

      # grapheme clusters
      assert Mold.parse({:string, max_length: 3}, "héy") == {:ok, "héy"}
    end

    test ":datetime" do
      assert Mold.parse(:datetime, "2023-06-22T07:34:04Z") == {:ok, ~U[2023-06-22 07:34:04Z]}

      assert Mold.parse(:datetime, "2T07:34:04Z") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "2T07:34:04Z"})]}

      assert Mold.parse(:datetime, "") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: ""})]}

      assert Mold.parse({:datetime, nilable: true}, nil) == {:ok, nil}
      assert Mold.parse({:datetime, nilable: true}, "") == {:ok, nil}
      assert Mold.parse(:datetime, ~U[2023-06-22 07:34:04Z]) == {:ok, ~U[2023-06-22 07:34:04Z]}
    end

    test ":naive_datetime" do
      assert Mold.parse(:naive_datetime, "2023-06-22T07:34:04") == {:ok, ~N[2023-06-22 07:34:04]}

      assert Mold.parse(:naive_datetime, "invalid") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "invalid"})]}

      assert Mold.parse(:naive_datetime, "") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: ""})]}

      assert Mold.parse({:naive_datetime, nilable: true}, nil) == {:ok, nil}
      assert Mold.parse({:naive_datetime, nilable: true}, "") == {:ok, nil}

      assert Mold.parse(:naive_datetime, ~N[2023-06-22 07:34:04]) ==
               {:ok, ~N[2023-06-22 07:34:04]}
    end

    test ":date" do
      assert Mold.parse(:date, "2023-06-22") == {:ok, ~D[2023-06-22]}

      assert Mold.parse(:date, "") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: ""})]}

      assert Mold.parse(:date, "2023-06-22T07:34:04Z") ==
               {:error,
                [Mold.Error.new(%{reason: :invalid_format, value: "2023-06-22T07:34:04Z"})]}

      assert Mold.parse({:date, nilable: true}, nil) == {:ok, nil}
      assert Mold.parse({:date, nilable: true}, "") == {:ok, nil}
      assert Mold.parse(:date, ~D[2023-06-22]) == {:ok, ~D[2023-06-22]}
    end

    test ":time" do
      assert Mold.parse(:time, "14:30:00") == {:ok, ~T[14:30:00]}
      assert Mold.parse(:time, "09:00:00.123") == {:ok, ~T[09:00:00.123]}

      assert Mold.parse(:time, "") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: ""})]}

      assert Mold.parse(:time, "not-a-time") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "not-a-time"})]}

      assert Mold.parse({:time, nilable: true}, nil) == {:ok, nil}
      assert Mold.parse({:time, nilable: true}, "") == {:ok, nil}
      assert Mold.parse(:time, ~T[14:30:00]) == {:ok, ~T[14:30:00]}
    end

    test "custom function" do
      assert Mold.parse(fn value -> {:ok, value} end, 1) == {:ok, 1}

      assert Mold.parse(fn _value -> {:error, :invalid_value} end, 1) ==
               {:error, [Mold.Error.new(%{reason: :invalid_value, value: 1})]}

      assert Mold.parse({fn _value -> {:ok, nil} end, nilable: true}, {}) == {:ok, nil}

      assert Mold.parse(fn _value -> {:ok, nil} end, {}) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: {}})]}

      assert_raise ArgumentError,
                   "Invalid parse function result, expected {:ok, value} or {:error, reason}",
                   fn ->
                     Mold.parse(fn value -> value end, 1)
                   end
    end

    test ":list" do
      # bare :list — validates it's a list, returns as-is
      assert Mold.parse(:list, [1, "two", :three]) == {:ok, [1, "two", :three]}

      assert Mold.parse(:list, "not a list") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: "not a list"})]}

      assert Mold.parse({:list, type: :string}, ["hello", "world"]) == {:ok, ["hello", "world"]}
      assert Mold.parse({:list, type: :string}, []) == {:ok, []}

      assert Mold.parse({:list, type: {:string, nilable: true}}, ["hello", nil]) ==
               {:ok, ["hello", nil]}

      assert Mold.parse({:list, type: :string}, ["hello", nil]) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, trace: [1], value: nil})]}

      assert Mold.parse({:list, type: :string}, "hello") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: "hello"})]}

      assert Mold.parse({:list, type: :string}, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:list, type: :string, nilable: true}, nil) == {:ok, nil}

      assert Mold.parse({:list, type: :date}, ["2024-01-01", "2025-01-01", "invalid1", "invalid2"]) ==
               {:error,
                [Mold.Error.new(%{reason: :invalid_format, trace: [2], value: "invalid1"})]}

      assert Mold.parse(
               {:list, type: {:list, type: :date}},
               [["2024-01-01", "2025-01-01"], ["invalid1", "invalid2"]]
             ) ==
               {:error,
                [Mold.Error.new(%{reason: :invalid_format, trace: [1, 0], value: "invalid1"})]}

      assert Mold.parse({:list, type: :string, reject_invalid: true}, ["hello", nil]) ==
               {:ok, ["hello"]}

      # min_length / max_length
      assert Mold.parse({:list, type: :integer, min_length: 1}, [1]) == {:ok, [1]}
      assert Mold.parse({:list, type: :integer, min_length: 2}, [1, 2, 3]) == {:ok, [1, 2, 3]}

      assert Mold.parse({:list, type: :integer, min_length: 2}, [1]) ==
               {:error, [Mold.Error.new(%{reason: {:too_short, min_length: 2}, value: [1]})]}

      assert Mold.parse({:list, type: :integer, min_length: 1}, []) ==
               {:error, [Mold.Error.new(%{reason: {:too_short, min_length: 1}, value: []})]}

      assert Mold.parse({:list, type: :integer, max_length: 3}, [1, 2]) == {:ok, [1, 2]}

      assert Mold.parse({:list, type: :integer, max_length: 2}, [1, 2, 3]) ==
               {:error, [Mold.Error.new(%{reason: {:too_long, max_length: 2}, value: [1, 2, 3]})]}

      assert Mold.parse({:list, type: :integer, min_length: 1, max_length: 3}, [1, 2]) ==
               {:ok, [1, 2]}

      # reject_invalid + min_length: length checked after filtering
      assert Mold.parse(
               {:list, type: :string, reject_invalid: true, min_length: 2},
               ["a", nil, "b"]
             ) == {:ok, ["a", "b"]}

      assert Mold.parse(
               {:list, type: :string, reject_invalid: true, min_length: 3},
               ["a", nil, "b"]
             ) ==
               {:error,
                [Mold.Error.new(%{reason: {:too_short, min_length: 3}, value: ["a", "b"]})]}
    end

    test ":tuple" do
      # bare :tuple — validates it's a tuple/list, returns as tuple
      assert Mold.parse(:tuple, {1, "two", :three}) == {:ok, {1, "two", :three}}
      assert Mold.parse(:tuple, [1, "two"]) == {:ok, {1, "two"}}

      assert Mold.parse(:tuple, "not a tuple") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: "not a tuple"})]}

      # from list
      assert Mold.parse({:tuple, elements: [:string, :integer]}, ["Alice", "25"]) ==
               {:ok, {"Alice", 25}}

      # from tuple
      assert Mold.parse({:tuple, elements: [:string, :integer]}, {"Alice", "25"}) ==
               {:ok, {"Alice", 25}}

      # wrong length
      assert Mold.parse({:tuple, elements: [:string, :integer]}, ["Alice"]) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:unexpected_length, expected: 2, got: 1},
                    value: ["Alice"]
                  })
                ]}

      assert Mold.parse({:tuple, elements: [:string]}, ["a", "b"]) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:unexpected_length, expected: 1, got: 2},
                    value: ["a", "b"]
                  })
                ]}

      # element parse error with trace
      assert Mold.parse({:tuple, elements: [:string, :integer]}, ["Alice", "abc"]) ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, trace: [1], value: "abc"})]}

      # collects all errors
      assert Mold.parse({:tuple, elements: [:integer, :integer]}, ["abc", "def"]) ==
               {:error,
                [
                  Mold.Error.new(%{reason: :invalid_format, trace: [0], value: "abc"}),
                  Mold.Error.new(%{reason: :invalid_format, trace: [1], value: "def"})
                ]}

      # wrong type
      assert Mold.parse({:tuple, elements: [:string]}, "hello") ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, value: "hello"})]}

      # nil handling
      assert Mold.parse({:tuple, elements: [:string]}, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:tuple, elements: [:string], nilable: true}, nil) == {:ok, nil}

      # nested containers in elements
      assert Mold.parse(
               {:tuple, elements: [:string, {:list, type: :integer}]},
               ["tag", ["1", "2", "3"]]
             ) == {:ok, {"tag", [1, 2, 3]}}
    end

    test ":map with keys and values" do
      assert Mold.parse({:map, keys: :string, values: :integer}, %{"a" => "1", "b" => "2"}) ==
               {:ok, %{"a" => 1, "b" => 2}}

      assert Mold.parse({:map, keys: :atom, values: :string}, %{"name" => "Alice"}) ==
               {:ok, %{name: "Alice"}}

      assert Mold.parse({:map, keys: :string, values: :integer}, %{"a" => "abc"}) ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "abc", trace: ["a"]})]}

      assert Mold.parse({:map, keys: :string, values: :integer}, %{}) == {:ok, %{}}

      assert Mold.parse({:map, keys: :atom, values: :string}, %{"nonexistent_atom_zzz" => "hello"}) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: :unknown_atom,
                    value: "nonexistent_atom_zzz",
                    trace: []
                  })
                ]}
    end

    test ":map" do
      assert Mold.parse(:map, %{"name" => "hello"}) == {:ok, %{"name" => "hello"}}

      assert Mold.parse(:map, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse({:map, nilable: true}, nil) == {:ok, nil}

      # source defaults to &Atom.to_string/1 — looks up string keys
      assert Mold.parse({:map, fields: [name: :string]}, %{"name" => "hello"}) ==
               {:ok, %{name: "hello"}}

      assert Mold.parse({:map, fields: [name: :string]}, %{name: "hello"}) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:missing_field, "name"},
                    trace: [:name],
                    value: %{name: "hello"}
                  })
                ]}

      assert Mold.parse({:map, fields: [name: :string]}, %{"name" => nil}) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, trace: [:name], value: nil})]}

      assert Mold.parse({:map, fields: [name: [type: :string, source: "name"]]}, %{
               "name" => "hello"
             }) ==
               {:ok, %{name: "hello"}}

      assert Mold.parse({:map, fields: [name: [type: :string, source: "name"]]}, %{name: "hello"}) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:missing_field, "name"},
                    trace: [:name],
                    value: %{name: "hello"}
                  })
                ]}

      assert Mold.parse({:map, fields: [name: [type: :string, source: ["details", "name"]]]}, %{
               "details" => %{"name" => "Alice"}
             }) ==
               {:ok, %{name: "Alice"}}

      assert Mold.parse({:map, fields: [name: [type: :string, source: ["details", "name"]]]}, %{
               "name" => "hello"
             }) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:missing_field, "details"},
                    trace: [:name],
                    value: %{"name" => "hello"}
                  })
                ]}

      assert Mold.parse({:map, fields: [name: [type: :string, source: ["details", "name"]]]}, %{
               "details" => "hello"
             }) ==
               {:error,
                [Mold.Error.new(%{reason: :unexpected_type, trace: [:name], value: "hello"})]}

      assert Mold.parse({:map, fields: [name: [type: :string, source: ["details", "name"]]]}, %{
               "details" => %{}
             }) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:missing_field, "name"},
                    trace: [:name],
                    value: %{}
                  })
                ]}

      assert Mold.parse(
               {:map, fields: [date: [type: :date, source: "date"]]},
               %{"date" => "invalid-2023-06-22"}
             ) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: :invalid_format,
                    trace: [:date],
                    value: "invalid-2023-06-22"
                  })
                ]}

      assert Mold.parse(
               {:map, fields: [address: {:map, fields: [street: :string, city: :string]}]},
               %{"address" => %{"street" => "123 Main St", "city" => "Anytown"}}
             ) == {:ok, %{address: %{street: "123 Main St", city: "Anytown"}}}
    end

    test ":map missing field with type opts but no default" do
      schema = {:map, fields: [name: [type: {:string, nilable: true}, source: "name"]]}

      assert Mold.parse(schema, %{}) ==
               {:error,
                [Mold.Error.new(%{reason: {:missing_field, "name"}, trace: [:name], value: %{}})]}
    end

    test ":map collects all errors" do
      schema =
        {:map,
         fields: [
           name: [type: :string, source: "name"],
           age: [type: :integer, source: "age"],
           email: [type: :string, source: "email"]
         ]}

      assert Mold.parse(schema, %{"name" => 123, "age" => "abc", "email" => "ok"}) ==
               {:error,
                [
                  Mold.Error.new(%{reason: :unexpected_type, trace: [:name], value: 123}),
                  Mold.Error.new(%{reason: :invalid_format, trace: [:age], value: "abc"})
                ]}
    end

    test ":map optional fields" do
      schema =
        {:map,
         fields: [
           name: [type: :string, source: "name"],
           bio: [type: :string, source: "bio", optional: true]
         ]}

      assert Mold.parse(schema, %{"name" => "Alice"}) == {:ok, %{name: "Alice"}}

      assert Mold.parse(schema, %{"name" => "Alice", "bio" => "hello"}) ==
               {:ok, %{name: "Alice", bio: "hello"}}

      assert Mold.parse(schema, %{"name" => "Alice", "bio" => nil}) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, trace: [:bio], value: nil})]}

      schema =
        {:map, fields: [bio: [type: {:string, nilable: true}, source: "bio", optional: true]]}

      assert Mold.parse(schema, %{}) == {:ok, %{}}
      assert Mold.parse(schema, %{"bio" => nil}) == {:ok, %{bio: nil}}
      assert Mold.parse(schema, %{"bio" => "hello"}) == {:ok, %{bio: "hello"}}

      schema = {:map, fields: [age: [type: :integer, source: "age", optional: true]]}
      assert Mold.parse(schema, %{}) == {:ok, %{}}

      assert Mold.parse(schema, %{"age" => "abc"}) ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, trace: [:age], value: "abc"})]}
    end

    test ":map reject_invalid with fields" do
      schema =
        {:map,
         reject_invalid: true,
         fields: [
           name: [type: :string, source: "name"],
           age: [type: :integer, source: "age", optional: true],
           bio: [type: :string, source: "bio", optional: true]
         ]}

      # optional fields with invalid values are dropped
      assert Mold.parse(schema, %{"name" => "Alice", "age" => "nope", "bio" => nil}) ==
               {:ok, %{name: "Alice"}}

      # optional fields with valid values are kept
      assert Mold.parse(schema, %{"name" => "Alice", "age" => "25", "bio" => "hello"}) ==
               {:ok, %{name: "Alice", age: 25, bio: "hello"}}

      # optional fields missing from input are still just omitted
      assert Mold.parse(schema, %{"name" => "Alice"}) == {:ok, %{name: "Alice"}}

      # required fields still fail
      assert Mold.parse(schema, %{"age" => "25"}) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:missing_field, "name"},
                    trace: [:name],
                    value: %{"age" => "25"}
                  })
                ]}

      # required fields with invalid values still fail
      assert Mold.parse(schema, %{"name" => 123, "age" => "nope"}) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_type, trace: [:name], value: 123})]}

      # without reject_invalid, optional fields with invalid values are errors
      schema_strict =
        {:map,
         fields: [
           name: [type: :string, source: "name"],
           age: [type: :integer, source: "age", optional: true]
         ]}

      assert Mold.parse(schema_strict, %{"name" => "Alice", "age" => "nope"}) ==
               {:error,
                [Mold.Error.new(%{reason: :invalid_format, trace: [:age], value: "nope"})]}
    end

    test ":map reject_invalid with keys/values" do
      schema = {:map, keys: :string, values: :integer, reject_invalid: true}

      # invalid entries are dropped
      assert Mold.parse(schema, %{"a" => "1", "b" => "nope", "c" => "3"}) ==
               {:ok, %{"a" => 1, "c" => 3}}

      # all valid
      assert Mold.parse(schema, %{"a" => "1", "b" => "2"}) ==
               {:ok, %{"a" => 1, "b" => 2}}

      # all invalid
      assert Mold.parse(schema, %{"a" => "nope", "b" => "nah"}) == {:ok, %{}}

      # invalid keys are also dropped
      schema_atom_keys = {:map, keys: :atom, values: :string, reject_invalid: true}

      assert Mold.parse(schema_atom_keys, %{"name" => "Alice", "nonexistent_atom_xyz" => "Bob"}) ==
               {:ok, %{name: "Alice"}}

      # without reject_invalid, invalid entries are errors
      schema_strict = {:map, keys: :string, values: :integer}

      assert Mold.parse(schema_strict, %{"a" => "1", "b" => "nope"}) ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, trace: ["b"], value: "nope"})]}
    end

    test "map shortcut %{}" do
      assert Mold.parse(%{name: :string, age: :integer}, %{"name" => "Alice", "age" => "25"}) ==
               {:ok, %{name: "Alice", age: 25}}

      assert Mold.parse(%{name: :string}, %{"name" => nil}) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, trace: [:name], value: nil})]}
    end

    test "list shortcut []" do
      assert Mold.parse([:string], ["a", "b"]) == {:ok, ["a", "b"]}

      assert Mold.parse([:integer], ["1", "abc"]) ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, trace: [1], value: "abc"})]}
    end

    test "nested shortcuts" do
      # list of maps
      assert Mold.parse([%{name: :string, value: :integer}], [
               %{"name" => "a", "value" => "1"},
               %{"name" => "b", "value" => "2"}
             ]) == {:ok, [%{name: "a", value: 1}, %{name: "b", value: 2}]}

      # map with list field
      assert Mold.parse(%{tags: [:string]}, %{"tags" => ["a", "b"]}) ==
               {:ok, %{tags: ["a", "b"]}}

      # error trace through shortcuts
      assert Mold.parse(%{items: [%{name: :string}]}, %{
               "items" => [%{"name" => "ok"}, %{"name" => nil}]
             }) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: :unexpected_nil,
                    trace: [:items, 1, :name],
                    value: nil
                  })
                ]}

      # error trace through {map_shortcut, opts}
      assert Mold.parse(%{data: {%{name: :string}, nilable: true}}, %{"data" => %{"name" => nil}}) ==
               {:error,
                [Mold.Error.new(%{reason: :unexpected_nil, trace: [:data, :name], value: nil})]}

      # error trace through {list_shortcut, opts}
      assert Mold.parse(%{items: {[:integer], reject_invalid: false}}, %{"items" => [1, "abc"]}) ==
               {:error,
                [Mold.Error.new(%{reason: :invalid_format, trace: [:items, 1], value: "abc"})]}
    end

    test "shortcuts in field opts type:" do
      schema =
        {:map,
         fields: [
           items: [
             source: "items",
             type: [
               %{
                 name: [source: "name", type: :string]
               }
             ]
           ]
         ]}

      assert Mold.parse(schema, %{"items" => [%{"name" => "Alice"}]}) ==
               {:ok, %{items: [%{name: "Alice"}]}}
    end

    test ":map source function" do
      # string keys
      schema = {:map, source: &Atom.to_string/1, fields: [name: :string, age: :integer]}

      assert Mold.parse(schema, %{"name" => "Alice", "age" => "25"}) ==
               {:ok, %{name: "Alice", age: 25}}

      # camelCase keys
      schema =
        {:map,
         source: &(Atom.to_string(&1) |> Macro.camelize()),
         fields: [
           user_name: :string,
           is_active: :boolean
         ]}

      assert Mold.parse(schema, %{"UserName" => "Alice", "IsActive" => "true"}) ==
               {:ok, %{user_name: "Alice", is_active: true}}

      # explicit field source: overrides map source:
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           name: :string,
           role: [type: :string, source: "userRole"]
         ]}

      assert Mold.parse(schema, %{"name" => "Alice", "userRole" => "admin"}) ==
               {:ok, %{name: "Alice", role: "admin"}}

      # recursive propagation to nested maps
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           address: {:map, fields: [street: :string, city: :string]}
         ]}

      assert Mold.parse(schema, %{"address" => %{"street" => "Main St", "city" => "NYC"}}) ==
               {:ok, %{address: %{street: "Main St", city: "NYC"}}}

      # nested map can override source:
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           meta: {:map, source: & &1, fields: [tag: :string]}
         ]}

      assert Mold.parse(schema, %{"meta" => %{tag: "ok"}}) == {:ok, %{meta: %{tag: "ok"}}}

      # propagates through lists
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           items: {:list, type: {:map, fields: [name: :string]}}
         ]}

      assert Mold.parse(schema, %{"items" => [%{"name" => "A"}, %{"name" => "B"}]}) ==
               {:ok, %{items: [%{name: "A"}, %{name: "B"}]}}

      # map -> list -> map with multiple fields
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           users:
             {:list,
              type:
                {:map,
                 fields: [
                   name: :string,
                   address: {:map, fields: [city: :string, zip: :string]}
                 ]}}
         ]}

      assert Mold.parse(schema, %{
               "users" => [
                 %{"name" => "Alice", "address" => %{"city" => "NYC", "zip" => "10001"}},
                 %{"name" => "Bob", "address" => %{"city" => "LA", "zip" => "90001"}}
               ]
             }) ==
               {:ok,
                %{
                  users: [
                    %{name: "Alice", address: %{city: "NYC", zip: "10001"}},
                    %{name: "Bob", address: %{city: "LA", zip: "90001"}}
                  ]
                }}

      # propagates through tuples
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           pair: {:tuple, elements: [%{name: :string}, %{name: :string}]}
         ]}

      assert Mold.parse(schema, %{"pair" => [%{"name" => "A"}, %{"name" => "B"}]}) ==
               {:ok, %{pair: {%{name: "A"}, %{name: "B"}}}}

      # with shortcut syntax
      schema = {%{name: :string, age: :integer}, source: &Atom.to_string/1}

      assert Mold.parse(schema, %{"name" => "Alice", "age" => "25"}) ==
               {:ok, %{name: "Alice", age: 25}}

      # source: propagates into map shortcut nested in fields
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           meta: %{tag: :string}
         ]}

      assert Mold.parse(schema, %{"meta" => %{"tag" => "ok"}}) == {:ok, %{meta: %{tag: "ok"}}}

      # source: propagates into {map_shortcut, opts} nested in fields
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           meta: {%{tag: :string}, nilable: true}
         ]}

      assert Mold.parse(schema, %{"meta" => nil}) == {:ok, %{meta: nil}}
      assert Mold.parse(schema, %{"meta" => %{"tag" => "ok"}}) == {:ok, %{meta: %{tag: "ok"}}}

      # source: propagates into list shortcut nested in fields
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           tags: [:string]
         ]}

      assert Mold.parse(schema, %{"tags" => ["a", "b"]}) == {:ok, %{tags: ["a", "b"]}}

      # source: propagates into {list_shortcut, opts} nested in fields
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           tags: {[:string], nilable: true}
         ]}

      assert Mold.parse(schema, %{"tags" => nil}) == {:ok, %{tags: nil}}
      assert Mold.parse(schema, %{"tags" => ["a"]}) == {:ok, %{tags: ["a"]}}

      # source: propagates through list shortcut into nested map shortcut
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           items: [%{name: :string}]
         ]}

      assert Mold.parse(schema, %{"items" => [%{"name" => "A"}]}) ==
               {:ok, %{items: [%{name: "A"}]}}

      # source: propagates through {list_shortcut, opts} into nested map
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           items: {[%{name: :string}], reject_invalid: true}
         ]}

      assert Mold.parse(schema, %{"items" => [%{"name" => "A"}, nil]}) ==
               {:ok, %{items: [%{name: "A"}]}}

      # error trace through shortcuts with source:
      schema =
        {:map,
         source: &Atom.to_string/1,
         fields: [
           items: [%{name: :string}]
         ]}

      assert Mold.parse(schema, %{"items" => [%{"name" => "ok"}, %{"name" => nil}]}) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: :unexpected_nil,
                    trace: [:items, 1, :name],
                    value: nil
                  })
                ]}
    end

    test "source with Access functions" do
      # Access.elem for tuple navigation
      schema =
        {:map,
         fields: [
           lat: [type: :float, source: ["coords", Access.elem(0)]],
           lng: [type: :float, source: ["coords", Access.elem(1)]]
         ]}

      assert Mold.parse(schema, %{"coords" => {49.8, 24.0}}) ==
               {:ok, %{lat: 49.8, lng: 24.0}}

      # Access.key/2 with default
      schema =
        {:map,
         fields: [
           theme: [
             type: :string,
             source: [Access.key("settings", %{"theme" => "light"}), "theme"]
           ]
         ]}

      # when key exists
      assert Mold.parse(schema, %{"settings" => %{"theme" => "dark"}}) == {:ok, %{theme: "dark"}}
      # when key is missing — Access.key/2 provides the default map
      assert Mold.parse(schema, %{}) == {:ok, %{theme: "light"}}

      # Access.at/1 for list navigation
      schema = {:map, fields: [first: [type: :string, source: ["items", Access.at(0)]]]}
      assert Mold.parse(schema, %{"items" => ["hello"]}) == {:ok, %{first: "hello"}}

      # Access.at/1 with negative index (last element)
      schema = {:map, fields: [last: [type: :string, source: ["items", Access.at(-1)]]]}
      assert Mold.parse(schema, %{"items" => ["a", "b", "c"]}) == {:ok, %{last: "c"}}

      # string → Access.at → string (full navigation chain)
      schema =
        {:map,
         fields: [
           city: [type: :string, source: ["users", Access.at(0), "city"]]
         ]}

      assert Mold.parse(schema, %{"users" => [%{"city" => "Kyiv"}, %{"city" => "NYC"}]}) ==
               {:ok, %{city: "Kyiv"}}

      # Access function on wrong data type
      schema = {:map, fields: [x: [type: :string, source: ["data", Access.elem(0)]]]}

      assert Mold.parse(schema, %{"data" => "not a tuple"}) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: :unexpected_type,
                    value: "not a tuple",
                    trace: [:x]
                  })
                ]}

      # combined: string → Access.at → string
      schema =
        {:map,
         fields: [
           tag: [type: :string, source: ["data", Access.at(0), "tag"]]
         ]}

      assert Mold.parse(schema, %{"data" => [%{"tag" => "ok"}, %{"tag" => "no"}]}) ==
               {:ok, %{tag: "ok"}}
    end

    test "shortcuts with options" do
      # map shortcut with nilable
      assert Mold.parse({%{name: :string}, nilable: true}, nil) == {:ok, nil}

      assert Mold.parse({%{name: :string}, nilable: true}, %{"name" => "Alice"}) ==
               {:ok, %{name: "Alice"}}

      # list shortcut with reject_invalid
      assert Mold.parse({[:string], reject_invalid: true}, ["a", nil, "b"]) == {:ok, ["a", "b"]}

      # list shortcut with nilable
      assert Mold.parse({[:integer], nilable: true}, nil) == {:ok, nil}
      assert Mold.parse({[:integer], nilable: true}, ["1", "2"]) == {:ok, [1, 2]}
    end

    test ":union" do
      schema =
        {:union,
         by: fn value -> value["type"] end,
         of: %{
           "user" => {:map, fields: [name: [type: :string, source: "name"]]},
           "bot" => {:map, fields: [version: [type: :integer, source: "version"]]}
         }}

      assert Mold.parse(schema, %{"type" => "user", "name" => "Alice"}) == {:ok, %{name: "Alice"}}
      assert Mold.parse(schema, %{"type" => "bot", "version" => "3"}) == {:ok, %{version: 3}}

      assert Mold.parse(schema, %{"type" => "unknown"}) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: {:unknown_variant, "unknown"},
                    value: %{"type" => "unknown"}
                  })
                ]}

      assert Mold.parse(schema, nil) ==
               {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: nil})]}

      assert Mold.parse(
               {:union, by: fn v -> v["type"] end, of: %{"a" => :string}, nilable: true},
               nil
             ) ==
               {:ok, nil}

      schema =
        {:union,
         by: fn
           value when is_list(value) -> :list
           value when is_binary(value) -> :single
         end,
         of: %{list: {:list, type: :string}, single: :string}}

      assert Mold.parse(schema, ["a", "b"]) == {:ok, ["a", "b"]}
      assert Mold.parse(schema, "hello") == {:ok, "hello"}
    end

    test ":in" do
      # list
      assert Mold.parse({:integer, in: [1, 2, 3]}, 1) == {:ok, 1}

      assert Mold.parse({:integer, in: [1, 2, 3]}, 4) ==
               {:error, [Mold.Error.new(%{reason: {:not_in, [1, 2, 3]}, value: 4})]}

      assert Mold.parse({:integer, in: [1, 2, 3]}, "2") == {:ok, 2}

      assert Mold.parse({:integer, in: [1, 2, 3]}, "4") ==
               {:error, [Mold.Error.new(%{reason: {:not_in, [1, 2, 3]}, value: 4})]}

      # range
      assert Mold.parse({:integer, in: 1..10}, 5) == {:ok, 5}

      assert Mold.parse({:integer, in: 1..10}, 11) ==
               {:error, [Mold.Error.new(%{reason: {:not_in, 1..10}, value: 11})]}

      # string
      assert Mold.parse({:string, in: ["a", "b", "c"]}, "a") == {:ok, "a"}

      assert Mold.parse({:string, in: ["a", "b", "c"]}, "d") ==
               {:error, [Mold.Error.new(%{reason: {:not_in, ["a", "b", "c"]}, value: "d"})]}

      # atom
      assert Mold.parse({:atom, in: [:foo, :bar]}, :foo) == {:ok, :foo}

      assert Mold.parse({:atom, in: [:foo, :bar]}, :baz) ==
               {:error, [Mold.Error.new(%{reason: {:not_in, [:foo, :bar]}, value: :baz})]}

      # float
      assert Mold.parse({:float, in: [1.0, 2.0, 3.0]}, 1.0) == {:ok, 1.0}

      assert Mold.parse({:float, in: [1.0, 2.0, 3.0]}, 4.0) ==
               {:error, [Mold.Error.new(%{reason: {:not_in, [1.0, 2.0, 3.0]}, value: 4.0})]}

      # MapSet
      set = MapSet.new(["x", "y"])
      assert Mold.parse({:string, in: set}, "x") == {:ok, "x"}

      assert Mold.parse({:string, in: set}, "z") ==
               {:error, [Mold.Error.new(%{reason: {:not_in, set}, value: "z"})]}

      # nilable + in: nil bypasses the in check
      assert Mold.parse({:integer, in: [1, 2, 3], nilable: true}, nil) == {:ok, nil}

      # combined with min/max: min/max runs first
      assert Mold.parse({:integer, min: 0, in: [1, 5, 10]}, -1) ==
               {:error, [Mold.Error.new(%{reason: {:too_small, min: 0}, value: -1})]}

      assert Mold.parse({:integer, min: 0, in: [1, 5, 10]}, 3) ==
               {:error, [Mold.Error.new(%{reason: {:not_in, [1, 5, 10]}, value: 3})]}
    end

    test ":default" do
      assert Mold.parse({:integer, default: 0}, nil) == {:ok, 0}
      assert Mold.parse({:integer, default: 0}, "5") == {:ok, 5}
      assert Mold.parse({:string, default: "N/A"}, nil) == {:ok, "N/A"}
      assert Mold.parse({:string, default: "N/A"}, "") == {:ok, "N/A"}
      assert Mold.parse({:string, default: "N/A"}, "hello") == {:ok, "hello"}
      assert Mold.parse({:string, default: fn -> "lazy" end}, nil) == {:ok, "lazy"}
      assert Mold.parse({:string, default: fn -> "lazy" end}, "hello") == {:ok, "hello"}
      assert Mold.parse({:integer, default: {Enum, :count, [[1, 2, 3]]}}, nil) == {:ok, 3}

      schema =
        {:map,
         fields: [
           name: [type: :string, source: "name"],
           role: [type: {:string, default: "user"}, source: "role"]
         ]}

      assert Mold.parse(schema, %{"name" => "Alice", "role" => nil}) ==
               {:ok, %{name: "Alice", role: "user"}}

      assert Mold.parse(schema, %{"name" => "Alice", "role" => "admin"}) ==
               {:ok, %{name: "Alice", role: "admin"}}

      assert Mold.parse(
               {:map, fields: [role: [type: {:string, default: "user"}, source: "role"]]},
               %{}
             ) ==
               {:ok, %{role: "user"}}

      schema =
        {:map, fields: [id: [type: {:string, default: fn -> "generated" end}, source: "id"]]}

      assert Mold.parse(schema, %{}) == {:ok, %{id: "generated"}}
      assert Mold.parse(schema, %{"id" => nil}) == {:ok, %{id: "generated"}}
      assert Mold.parse(schema, %{"id" => "existing"}) == {:ok, %{id: "existing"}}

      schema =
        {:map,
         fields: [
           bio: [type: {:string, default: "none"}, source: "bio", optional: true]
         ]}

      assert Mold.parse(schema, %{}) == {:ok, %{}}
      assert Mold.parse(schema, %{"bio" => nil}) == {:ok, %{bio: "none"}}
      assert Mold.parse(schema, %{"bio" => "hello"}) == {:ok, %{bio: "hello"}}

      # nilable + default: explicit nil is preserved, default only for missing keys
      assert Mold.parse({:integer, nilable: true, default: 2}, nil) == {:ok, nil}
      assert Mold.parse({:string, nilable: true, default: "fallback"}, nil) == {:ok, nil}

      schema = %{score: {:integer, nilable: true, default: 0}}

      assert Mold.parse(schema, %{"score" => nil}) == {:ok, %{score: nil}}
      assert Mold.parse(schema, %{"score" => "5"}) == {:ok, %{score: 5}}
      assert Mold.parse(schema, %{}) == {:ok, %{score: 0}}
    end
  end

  describe "transform and validate options" do
    test "transform applies after parsing" do
      assert Mold.parse({:string, transform: &String.downcase/1}, "HELLO") == {:ok, "hello"}
      assert Mold.parse({:integer, transform: &(&1 * 2)}, "5") == {:ok, 10}
    end

    test "validate applies after transform" do
      assert Mold.parse({:integer, validate: &(&1 > 0)}, "5") == {:ok, 5}

      assert Mold.parse({:integer, validate: &(&1 > 0)}, "-1") ==
               {:error, [Mold.Error.new(%{reason: :validation_failed, value: -1})]}
    end

    test "transform then validate" do
      type = {:string, transform: &String.downcase/1, validate: &String.contains?(&1, "@")}

      assert Mold.parse(type, "USER@EXAMPLE.COM") == {:ok, "user@example.com"}

      assert Mold.parse(type, "not-email") ==
               {:error, [Mold.Error.new(%{reason: :validation_failed, value: "not-email"})]}
    end

    test "validate runs after in" do
      type = {:integer, in: 1..100, validate: &(rem(&1, 2) == 0)}

      assert Mold.parse(type, "4") == {:ok, 4}

      assert Mold.parse(type, "3") ==
               {:error, [Mold.Error.new(%{reason: :validation_failed, value: 3})]}

      assert Mold.parse(type, "200") ==
               {:error, [Mold.Error.new(%{reason: {:not_in, 1..100}, value: 200})]}
    end

    test "transform and validate work inside maps" do
      schema = %{
        email: {:string, transform: &String.downcase/1, validate: &String.contains?(&1, "@")}
      }

      assert Mold.parse(schema, %{"email" => "USER@EXAMPLE.COM"}) ==
               {:ok, %{email: "user@example.com"}}
    end
  end

  describe "nested containers" do
    test "error trace through map > list > map" do
      assert Mold.parse(
               {:map,
                fields: [
                  datetimes: [
                    type:
                      {:list,
                       type: {:map, fields: [datetime: [type: :datetime, source: "dateTime"]]}},
                    source: "dateTimes"
                  ]
                ]},
               %{
                 "dateTimes" => [
                   %{"dateTime" => "2023-06-22T07:34:04Z"},
                   %{"dateTime" => "invalid"},
                   %{"dateTime" => "2024-06-22T07:34:04Z"}
                 ]
               }
             ) ==
               {:error,
                [
                  Mold.Error.new(%{
                    reason: :invalid_format,
                    trace: [:datetimes, 1, :datetime],
                    value: "invalid"
                  })
                ]}
    end

    test "reject_invalid in nested list" do
      assert Mold.parse(
               {:map,
                fields: [
                  datetimes: [
                    type:
                      {:list,
                       reject_invalid: true,
                       type: {:map, fields: [datetime: [type: :datetime, source: "dateTime"]]}},
                    source: "dateTimes"
                  ]
                ]},
               %{
                 "dateTimes" => [
                   %{"dateTime" => "2023-06-22T07:34:04Z"},
                   %{"dateTime" => "invalid"},
                   %{"dateTime" => "2024-06-22T07:34:04Z"},
                   nil
                 ]
               }
             ) ==
               {:ok,
                %{
                  datetimes: [
                    %{datetime: ~U[2023-06-22 07:34:04Z]},
                    %{datetime: ~U[2024-06-22 07:34:04Z]}
                  ]
                }}
    end

    test "recursive type with custom function" do
      assert Mold.RecursiveFixture.parse_comment(%{
               "text" => "hello",
               "replies" => [
                 %{"text" => "nested", "replies" => nil},
                 %{
                   "text" => "deep",
                   "replies" => [
                     %{"text" => "leaf", "replies" => nil}
                   ]
                 }
               ]
             }) ==
               {:ok,
                %{
                  text: "hello",
                  replies: [
                    %{text: "nested", replies: nil},
                    %{
                      text: "deep",
                      replies: [
                        %{text: "leaf", replies: nil}
                      ]
                    }
                  ]
                }}

      assert {:error, [%Mold.Error{trace: [:replies, 0, :replies, 0, :text]} | _]} =
               Mold.RecursiveFixture.parse_comment(%{
                 "text" => "ok",
                 "replies" => [
                   %{
                     "text" => "ok",
                     "replies" => [
                       %{"text" => 123}
                     ]
                   }
                 ]
               })
    end

    test "error trace with map shortcut + opts as field type" do
      # {%{...}, opts} inside a map field — triggers put_trace_to_container_types({map, opts}, trace)
      schema = %{data: {%{name: :string}, nilable: true}}

      assert Mold.parse(schema, %{"data" => %{"name" => 123}}) ==
               {:error,
                [Mold.Error.new(%{reason: :unexpected_type, value: 123, trace: [:data, :name]})]}

      assert Mold.parse(schema, %{"data" => nil}) == {:ok, %{data: nil}}
    end

    test "error trace with list shortcut as field type" do
      # [...] inside a map field — triggers put_trace_to_container_types([type], trace)
      schema = %{tags: [:string]}

      assert Mold.parse(schema, %{"tags" => ["ok", 123]}) ==
               {:error,
                [Mold.Error.new(%{reason: :unexpected_type, value: 123, trace: [:tags, 1]})]}
    end

    test "error trace with list shortcut + opts as field type" do
      # {[...], opts} inside a map field — triggers put_trace_to_container_types({[type], opts}, trace)
      schema = %{tags: {[:string], reject_invalid: true}}

      assert Mold.parse(schema, %{"tags" => ["ok", 123]}) == {:ok, %{tags: ["ok"]}}
    end

    test "error trace with function + opts as field type" do
      parse_fn = fn
        v when is_binary(v) -> {:ok, String.upcase(v)}
        _v -> {:error, :not_a_string}
      end

      schema = %{name: {parse_fn, nilable: true}}

      assert Mold.parse(schema, %{"name" => nil}) == {:ok, %{name: nil}}
      assert Mold.parse(schema, %{"name" => "hello"}) == {:ok, %{name: "HELLO"}}
    end

    test "custom function without trace returns errors as-is" do
      parse_fn = fn value -> Mold.parse(:integer, value) end

      assert Mold.parse(parse_fn, "abc") ==
               {:error, [Mold.Error.new(%{reason: :invalid_format, value: "abc"})]}
    end

    test "custom function errors get trace prepended in nested context" do
      parse_fn = fn _value -> {:error, [Mold.Error.new(%{reason: :custom_error, value: nil})]} end

      assert Mold.parse(%{field: parse_fn}, %{"field" => "x"}) ==
               {:error, [Mold.Error.new(%{reason: :custom_error, value: nil, trace: [:field]})]}
    end

    test "custom function returning bare :error" do
      parse_fn = fn _value -> :error end

      assert Mold.parse(parse_fn, "abc") ==
               {:error, [Mold.Error.new(%{reason: :invalid, value: "abc"})]}
    end
  end

  describe "documented error reasons" do
    # Shared (all types)

    test ":unexpected_nil" do
      assert {:error, [%Mold.Error{reason: :unexpected_nil}]} = Mold.parse(:string, nil)
    end

    test ":unexpected_type" do
      assert {:error, [%Mold.Error{reason: :unexpected_type}]} = Mold.parse(:string, 123)
    end

    test "{:not_in, enumerable}" do
      assert {:error, [%Mold.Error{reason: {:not_in, [1, 2]}}]} =
               Mold.parse({:integer, in: [1, 2]}, "3")
    end

    test ":validation_failed" do
      assert {:error, [%Mold.Error{reason: :validation_failed}]} =
               Mold.parse({:integer, validate: &(&1 > 0)}, "-1")
    end

    # String

    test "string {:invalid_format, regex}" do
      format = ~r/^[a-z]+$/

      assert {:error, [%Mold.Error{reason: {:invalid_format, ^format}}]} =
               Mold.parse({:string, format: format}, "ABC")
    end

    test "string {:too_short, min_length: n}" do
      assert {:error, [%Mold.Error{reason: {:too_short, min_length: 3}}]} =
               Mold.parse({:string, min_length: 3}, "ab")
    end

    test "string {:too_long, max_length: n}" do
      assert {:error, [%Mold.Error{reason: {:too_long, max_length: 2}}]} =
               Mold.parse({:string, max_length: 2}, "abc")
    end

    # Integer

    test "integer :invalid_format" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} = Mold.parse(:integer, "abc")
    end

    test "integer {:too_small, min: n}" do
      assert {:error, [%Mold.Error{reason: {:too_small, min: 0}}]} =
               Mold.parse({:integer, min: 0}, "-1")
    end

    test "integer {:too_large, max: n}" do
      assert {:error, [%Mold.Error{reason: {:too_large, max: 10}}]} =
               Mold.parse({:integer, max: 10}, "11")
    end

    # Float

    test "float :invalid_format" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} = Mold.parse(:float, "abc")
    end

    test "float {:too_small, min: n}" do
      assert {:error, [%Mold.Error{reason: {:too_small, min: +0.0}}]} =
               Mold.parse({:float, min: 0.0}, "-1.0")
    end

    test "float {:too_large, max: n}" do
      assert {:error, [%Mold.Error{reason: {:too_large, max: 1.0}}]} =
               Mold.parse({:float, max: 1.0}, "2.0")
    end

    # Boolean

    test "boolean :invalid_format" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} = Mold.parse(:boolean, "yes")
    end

    # Atom

    test "atom :unknown_atom" do
      assert {:error, [%Mold.Error{reason: :unknown_atom}]} =
               Mold.parse(:atom, "nonexistent_atom_zzz_xxx")
    end

    # Date & Time

    test "date :invalid_format" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} = Mold.parse(:date, "nope")
    end

    test "date :invalid_date" do
      assert {:error, [%Mold.Error{reason: :invalid_date}]} = Mold.parse(:date, "2024-13-01")
    end

    test "datetime :invalid_format" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} = Mold.parse(:datetime, "nope")
    end

    test "datetime :missing_offset" do
      assert {:error, [%Mold.Error{reason: :missing_offset}]} =
               Mold.parse(:datetime, "2024-01-02T03:04:05")
    end

    test "time :invalid_format" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} = Mold.parse(:time, "nope")
    end

    test "time :invalid_time" do
      assert {:error, [%Mold.Error{reason: :invalid_time}]} = Mold.parse(:time, "25:00:00")
    end

    test "naive_datetime :invalid_format" do
      assert {:error, [%Mold.Error{reason: :invalid_format}]} =
               Mold.parse(:naive_datetime, "nope")
    end

    test "naive_datetime :invalid_time" do
      assert {:error, [%Mold.Error{reason: :invalid_time}]} =
               Mold.parse(:naive_datetime, "2024-01-02T25:00:00")
    end

    # Map

    test "map {:missing_field, key}" do
      assert {:error, [%Mold.Error{reason: {:missing_field, "name"}}]} =
               Mold.parse(%{name: :string}, %{})
    end

    # List

    test "list {:too_short, min_length: n}" do
      assert {:error, [%Mold.Error{reason: {:too_short, min_length: 1}}]} =
               Mold.parse({[:integer], min_length: 1}, [])
    end

    test "list {:too_long, max_length: n}" do
      assert {:error, [%Mold.Error{reason: {:too_long, max_length: 1}}]} =
               Mold.parse({[:integer], max_length: 1}, [1, 2])
    end

    # Tuple

    test "tuple {:unexpected_length, expected: n, got: n}" do
      assert {:error, [%Mold.Error{reason: {:unexpected_length, expected: 2, got: 1}}]} =
               Mold.parse({:tuple, elements: [:string, :integer]}, ["only_one"])
    end

    # Union

    test "union {:unknown_variant, key}" do
      schema = {:union, by: fn v -> v["type"] end, of: %{"a" => :string}}

      assert {:error, [%Mold.Error{reason: {:unknown_variant, "b"}}]} =
               Mold.parse(schema, %{"type" => "b"})
    end

    # Custom function

    test "custom function :invalid" do
      assert {:error, [%Mold.Error{reason: :invalid}]} =
               Mold.parse(fn _ -> :error end, "x")
    end

    test "custom function passthrough reason" do
      assert {:error, [%Mold.Error{reason: :my_custom_reason}]} =
               Mold.parse(fn _ -> {:error, :my_custom_reason} end, "x")
    end
  end

  describe "trace" do
    test "Access functions in source produce clean schema trace" do
      schema =
        {:map,
         fields: [
           lat: [type: :float, source: ["coords", Access.at(0)]]
         ]}

      input = %{"coords" => ["not_a_float"]}
      {:error, errors} = Mold.parse(schema, input)

      assert [%{trace: [:lat]}] = errors
    end
  end
end
