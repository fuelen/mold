# Mold

A tiny, zero-dependency parsing library for external payloads.

Mold parses JSON APIs, webhooks, HTTP params and other external input into clean Elixir terms.

## Philosophy

External data crosses the boundary as strings and maps with string keys. Before you can work with it, you need to turn `%{"age" => "25"}` into `%{age: 25}` — coerce types, rename keys, check structure. Mold does this in one step with `parse/2`.

Mold follows the [Parse, don't validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) approach: instead of checking data and returning a boolean, `parse/2` transforms untyped input into well-typed output or returns structured errors. There is no `Mold.valid?/2`. You parse at the boundary, and from that point on you work with clean Elixir terms.

This doesn't mean the data is "valid" in every sense — a record might already exist in the database, a token might have expired, a concurrent process might have changed things. Mold handles structural correctness: types, shapes, constraints. Business logic is a separate layer.

Types in Mold are plain data. A type is just a value: you can build it at runtime, store in a variable, compose dynamically, or pass between modules.

## Installation

```elixir
def deps do
  [
    {:mold, "~> 0.1.0"}
  ]
end
```

## Quick start

```elixir
# Primitives
Mold.parse(:string, "  hello  ")        #=> {:ok, "hello"}
Mold.parse(:integer, "42")              #=> {:ok, 42}
Mold.parse(:boolean, "true")            #=> {:ok, true}
Mold.parse(:date, "2024-01-02")         #=> {:ok, ~D[2024-01-02]}

# Maps — string keys are the default
Mold.parse(%{name: :string, age: :integer}, %{"name" => "Alice", "age" => "25"})
#=> {:ok, %{name: "Alice", age: 25}}

# Lists
Mold.parse([:string], ["a", "b", "c"])  #=> {:ok, ["a", "b", "c"]}

# Custom parse functions
Mold.parse(&Version.parse/1, "1.0.0")   #=> {:ok, %Version{major: 1, minor: 0, patch: 0}}

# Options
Mold.parse({:integer, min: 0, max: 100}, "50")              #=> {:ok, 50}
Mold.parse({:string, nilable: true}, "")                     #=> {:ok, nil}
Mold.parse({:integer, default: 0}, nil)                      #=> {:ok, 0}
Mold.parse({:string, transform: &String.downcase/1}, "HI")   #=> {:ok, "hi"}
Mold.parse({:atom, in: [:draft, :published]}, "draft")       #=> {:ok, :draft}

# Errors include the path to the failing value
Mold.parse(%{items: [%{name: :string}]}, %{"items" => [%{"name" => "A"}, %{}]})
#=> {:error, [%Mold.Error{reason: {:missing_field, "name"}, trace: ["items", 1], ...}]}
```

## Types

A Mold type is plain Elixir data. Every type is one of three things:

| Form | Example | Meaning |
|---|---|---|
| Atom | `:string` | Built-in type with default options |
| Function | `&MyApp.parse_email/1` | Custom parse `fn value -> {:ok, v} \| {:error, r} \| :error end` |
| Tuple | `{:integer, min: 0}` | Type (atom or function) with options |

Maps and lists have a shortcut syntax:

| Shortcut | Example | Expands to |
|---|---|---|
| Map | `%{name: :string}` | `{:map, fields: [name: :string]}` |
| List | `[:string]` | `{:list, type: :string}` |

These forms compose into any shape:

```elixir
%{
  name: :string,
  age: {:integer, min: 0},
  address: %{city: :string, zip: :string},
  tags: [:string]
}
```

See [the documentation](https://hexdocs.pm/mold) for the full guide, types reference, and options.

## License

Apache-2.0
