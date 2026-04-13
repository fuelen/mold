defmodule Mold do
  @moduledoc """
  A tiny, zero-dependency parsing library for external payloads.

  Mold parses JSON APIs, webhooks, HTTP params and other external input into clean Elixir terms.

  See the [Cheatsheet](cheatsheet.cheatmd) for a quick reference.

  ## Types

  A Mold type is plain Elixir data. Every type is one of three things:

  | Form | Example | Meaning |
  |---|---|---|
  | Atom | `:string` | Built-in type with default options |
  | Function | `&MyApp.parse_email/1` | Custom parse `fn value -> {:ok, v} \\| {:error, r} \\| :error end` |
  | Tuple | `{:integer, min: 0}` | Type (atom or function) with options |

  Options refine the type: `:integer` is one type, `{:integer, min: 0}` is a different,
  more precise type — like saying `positive_integer`. Each combination describes
  a specific set of values, not a type with separate validation rules bolted on.

  Maps and lists have a shortcut syntax:

  | Shortcut | Example | Expands to |
  |---|---|---|
  | Map | `%{name: :string}` | `{:map, fields: [name: :string]}` |
  | List | `[:string]` | `{:list, type: :string}` |

  Shortcuts support options via tuple: `{%{name: :string}, nilable: true}`,
  `{[:string], reject_invalid: true}`. These can be nested: `[%{name: :string}]` is a list of maps.

  Shortcuts don't support field options like `source:` or `optional:`.
  Use the full `{:map, fields: [...]}` syntax when you need those.

  See the type definitions below for details and examples on each built-in type.

  ## Shared options

  All types accept the following options:

    * `:nilable` – allows `nil` as a valid value.
    * `:default` – substitutes `value` when nil or missing. Accepts a static value,
      a zero-arity function, or an MFA tuple `{mod, fun, args}` for lazy evaluation.
      When combined with `nilable`, explicit `nil` is preserved and the default only
      applies to missing fields. Note: a 3-tuple `{atom, atom, list}` is always treated as MFA.
      To use such a tuple as a static default, wrap it: `default: fn -> {Mod, :fun, []} end`.
    * `:in` – validates that the parsed value is a member of the given `t:Enumerable.t/0`
      (list, range, MapSet, etc.).
    * `:transform` – a function applied to the parsed value before validation.
      E.g. `{:string, transform: &String.downcase/1}`.
    * `:validate` – a function that must return `true` for the value to be accepted.
      Runs after `:transform` and `:in`. Fails with reason `:validation_failed` on `false`.
      E.g. `{:integer, validate: &(rem(&1, 2) == 0)}`.

  Execution order: parse → transform → in → validate.

  Errors include a `:trace` that points to the exact failing path (schema field names, list indexes, and/or dynamic map keys).
  See `Mold.Error` for the error structure and all possible reasons, and the
  [Formatting errors](formatting-errors.md) guide for how to present them in your application.

  """

  @moduledoc groups: [
               %{
                 title: "Types: Basic",
                 description:
                   "Primitive scalar types: strings, integers, floats, booleans, and atoms."
               },
               %{title: "Types: Date & Time", description: "ISO8601-based date and time types."},
               %{title: "Types: Collections", description: "Maps, lists, and tuples."},
               %{title: "Types: Composite", description: "Types that combine other types."},
               %{
                 title: "Types: Custom",
                 description:
                   "Any `fn value -> {:ok, parsed} | {:error, reason} | :error end` is accepted wherever a type is expected. Wrap in a tuple to add shared options: `{my_fn, nilable: true}`."
               }
             ]

  @typedoc group: "Types: Custom"
  @typedoc """
  A function that attempts to parse a value.

  Must return `{:ok, parsed}`, `{:error, reason}`, or bare `:error`.

  Bare `:error` is converted to `{:error, :invalid}` — this lets you use
  standard library functions like `&Version.parse/1` directly as types.

  Can also return `{:error, [%Mold.Error{}]}` — errors are passed through
  with trace propagation. This is useful when a parse function calls
  `Mold.parse/2` internally, including recursive types:

      defmodule Comment do
        def parse_comment(value) do
          Mold.parse(%{text: :string, replies: {[&parse_comment/1], nilable: true}}, value)
        end
      end
  """
  @type parse_function() :: (any() -> {:ok, any()} | {:error, [Mold.Error.t()] | any()} | :error)

  @typedoc """
  Default value: a static value, a zero-arity function, or an MFA tuple.
  """
  @type default() :: any() | (-> any()) | {module(), atom(), [any()]}

  @typedoc """
  Transform function applied to the parsed value.
  """
  @type transform() :: (any() -> any())

  @typedoc """
  Validate function. Must return `true` for the value to be accepted.
  """
  @type validate() :: (any() -> boolean())

  @typedoc group: "Types: Basic"
  @typedoc """
  String type. Accepts binaries; trims whitespace by default.

  Empty strings (and whitespace-only with trim) are treated as `nil`.

  Options:
  - `:trim` – trim whitespace before validation (default: `true`)
  - `:format` – validate against a `t:Regex.t/0` pattern
  - `:min_length` – minimum string length (inclusive, in grapheme clusters)
  - `:max_length` – maximum string length (inclusive, in grapheme clusters)
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:string, "  hello  ")
      {:ok, "hello"}

      iex> Mold.parse(:string, "   ")
      {:error, [%Mold.Error{reason: :unexpected_nil, value: "   "}]}

      iex> Mold.parse({:string, nilable: true}, "")
      {:ok, nil}

      iex> Mold.parse({:string, min_length: 3, max_length: 50}, "hi")
      {:error, [%Mold.Error{reason: {:too_short, min_length: 3}, value: "hi"}]}

      iex> format = ~r/^[a-z]+$/
      iex> Mold.parse({:string, format: format}, "Hello")
      {:error, [%Mold.Error{reason: {:invalid_format, format}, value: "Hello"}]}

      iex> Mold.parse({:string, trim: false}, "  hello  ")
      {:ok, "  hello  "}
  """
  @type string_type() ::
          {:string,
           trim: boolean(),
           nilable: boolean(),
           default: default(),
           format: Regex.t(),
           min_length: non_neg_integer(),
           max_length: non_neg_integer(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :string

  @typedoc group: "Types: Basic"
  @typedoc """
  Atom type. Accepts atoms and strings convertible to existing atoms
  (via `String.to_existing_atom/1`).

  Options:
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse({:atom, in: [:draft, :published, :archived]}, "draft")
      {:ok, :draft}

      iex> Mold.parse(:atom, "nonexistent_atom_xxx")
      {:error, [%Mold.Error{reason: :unknown_atom, value: "nonexistent_atom_xxx"}]}

      iex> Mold.parse({:atom, in: [:draft, :published]}, "archived")
      {:error, [%Mold.Error{reason: {:not_in, [:draft, :published]}, value: :archived}]}

      iex> Mold.parse({:atom, default: :draft}, nil)
      {:ok, :draft}
  """
  @type atom_type() ::
          {:atom,
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :atom

  @typedoc group: "Types: Basic"
  @typedoc """
  Boolean type. Accepts booleans, strings (`"true"`, `"false"`, `"1"`, `"0"`), and integers (`1`, `0`).

  Options:
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:boolean, "true")
      {:ok, true}

      iex> Mold.parse(:boolean, "0")
      {:ok, false}

      iex> Mold.parse(:boolean, "yes")
      {:error, [%Mold.Error{reason: :invalid_format, value: "yes"}]}

      iex> Mold.parse({:boolean, default: false}, nil)
      {:ok, false}
  """
  @type boolean_type() ::
          {:boolean,
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :boolean

  @typedoc group: "Types: Basic"
  @typedoc """
  Integer type. Accepts integers and strings parseable as integers.

  Options:
  - `:min` – minimum value (inclusive)
  - `:max` – maximum value (inclusive)
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:integer, "42")
      {:ok, 42}

      iex> Mold.parse({:integer, min: 0, max: 100}, "150")
      {:error, [%Mold.Error{reason: {:too_large, max: 100}, value: 150}]}

      iex> Mold.parse(:integer, "abc")
      {:error, [%Mold.Error{reason: :invalid_format, value: "abc"}]}

      iex> Mold.parse({:integer, in: 1..10}, "5")
      {:ok, 5}
  """
  @type integer_type() ::
          {:integer,
           nilable: boolean(),
           default: default(),
           min: integer(),
           max: integer(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :integer

  @typedoc group: "Types: Basic"
  @typedoc """
  Float type. Accepts floats, integers (promoted to float), and strings parseable as floats.

  Options:
  - `:min` – minimum value (inclusive)
  - `:max` – maximum value (inclusive)
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:float, "3.14")
      {:ok, 3.14}

      iex> Mold.parse(:float, 42)
      {:ok, 42.0}

      iex> Mold.parse({:float, min: 0.0, max: 1.0}, "1.5")
      {:error, [%Mold.Error{reason: {:too_large, max: 1.0}, value: 1.5}]}
  """
  @type float_type() ::
          {:float,
           nilable: boolean(),
           default: default(),
           min: number(),
           max: number(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :float

  @typedoc group: "Types: Date & Time"
  @typedoc """
  DateTime type. Accepts `t:DateTime.t/0` or ISO8601 datetime string.
  Empty strings are treated as `nil`.

  Options:
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:datetime, "2024-01-02T03:04:05Z")
      {:ok, ~U[2024-01-02 03:04:05Z]}

      iex> Mold.parse(:datetime, ~U[2024-01-02 03:04:05Z])
      {:ok, ~U[2024-01-02 03:04:05Z]}

      iex> Mold.parse(:datetime, "invalid")
      {:error, [%Mold.Error{reason: :invalid_format, value: "invalid"}]}

      iex> Mold.parse({:datetime, nilable: true}, "")
      {:ok, nil}
  """
  @type datetime_type() ::
          {:datetime,
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :datetime

  @typedoc group: "Types: Date & Time"
  @typedoc """
  NaiveDateTime type. Accepts `t:NaiveDateTime.t/0` or ISO8601 datetime string (without timezone).
  Empty strings are treated as `nil`.

  Options:
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:naive_datetime, "2024-01-02T03:04:05")
      {:ok, ~N[2024-01-02 03:04:05]}

      iex> Mold.parse(:naive_datetime, "invalid")
      {:error, [%Mold.Error{reason: :invalid_format, value: "invalid"}]}
  """
  @type naive_datetime_type() ::
          {:naive_datetime,
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :naive_datetime

  @typedoc group: "Types: Date & Time"
  @typedoc """
  Date type. Accepts `t:Date.t/0` or ISO8601 date string.
  Empty strings are treated as `nil`.

  Options:
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:date, "2024-01-02")
      {:ok, ~D[2024-01-02]}

      iex> Mold.parse(:date, "2024-13-01")
      {:error, [%Mold.Error{reason: :invalid_date, value: "2024-13-01"}]}

      iex> year_2024 = Date.range(~D[2024-01-01], ~D[2024-12-31])
      iex> Mold.parse({:date, in: year_2024}, "2025-01-01")
      {:error, [%Mold.Error{reason: {:not_in, year_2024}, value: ~D[2025-01-01]}]}
  """
  @type date_type() ::
          {:date,
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :date

  @typedoc group: "Types: Date & Time"
  @typedoc """
  Time type. Accepts `t:Time.t/0` or ISO8601 time string.
  Empty strings are treated as `nil`.

  Options:
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse(:time, "14:30:00")
      {:ok, ~T[14:30:00]}

      iex> Mold.parse(:time, "25:00:00")
      {:error, [%Mold.Error{reason: :invalid_time, value: "25:00:00"}]}
  """
  @type time_type() ::
          {:time,
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :time

  @typedoc group: "Types: Composite"
  @typedoc """
  Union type. Selects which type to apply based on the value.

  The `by` function receives the raw value and must return a variant
  that is looked up in `of`.

  Options:
  - `:by` – function that takes the raw value and returns a variant (required)
  - `:of` – map of variant => `t:t/0` (required)
  - `:source` – a function `(field_name -> any())` that propagates to all variant types
    containing maps. Variants with their own explicit `source` are not overridden.
  - [Shared options](#module-shared-options)

  ### Examples

      iex> schema = {:union,
      ...>   by: fn value -> value["type"] end,
      ...>   of: %{
      ...>     "user" => %{name: :string},
      ...>     "bot"  => %{version: :integer}
      ...>   }}
      iex> Mold.parse(schema, %{"type" => "user", "name" => "Alice"})
      {:ok, %{name: "Alice"}}
      iex> Mold.parse(schema, %{"type" => "bot", "version" => "3"})
      {:ok, %{version: 3}}
      iex> Mold.parse(schema, %{"type" => "admin"})
      {:error, [%Mold.Error{reason: {:unknown_variant, "admin"}, value: %{"type" => "admin"}}]}

  Use a catch-all in `by` to handle unexpected input types:

      iex> schema = {:union,
      ...>   by: fn
      ...>     %{"type" => type} -> type
      ...>     _ -> :unknown
      ...>   end,
      ...>   of: %{
      ...>     "user" => %{name: :string},
      ...>     "bot"  => %{version: :integer}
      ...>   }}
      iex> Mold.parse(schema, 123)
      {:error, [%Mold.Error{reason: {:unknown_variant, :unknown}, value: 123}]}
  """
  @type union_type() ::
          {:union,
           by: (any() -> any()),
           of: %{any() => t()},
           source: source_fn(),
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}

  @type source_fn :: (term() -> any())
  @type source_step :: term() | Access.access_fun(any(), any())
  @type source_path :: source_step | [source_step]

  @typedoc group: "Types: Collections"
  @typedoc """
  Map type. Three forms:

  - Bare `:map` — validates the value is a map, returns as-is (passthrough).
  - `{:map, fields: [...]}` — validates maps field-by-field. Field names are typically atoms
    (the default `source` converts them to strings for lookup); non-atom keys require a custom `source`.
  - `{:map, keys: t, values: t}` — homogeneous map, parses all keys and values.

  Options for `fields`:
  - `:fields` – list of `{name, type}` tuples where each value is either a `t:t/0` (`name: :string`)
    or a keyword list with field options:
    - `:type` – the field type `t:t/0` (required)
    - `:source` – where to read the value from. A single step or a list of steps (path),
      like `get_in/2`. Each step can be:
      - function – `Access` accessor (e.g. `Access.at/1`, `Access.elem/1`, `Access.key/2`)
      - any other term – key lookup via `Access.fetch/2` (string, atom, integer, etc.)
    - `:optional` – when `true`, omit field from result when missing from input
  - `:source` – a function `(field_name -> any())` that derives the source key from each field name
    (e.g. `source: &(Atom.to_string(&1) |> Macro.camelize())`).
    Defaults to `&Atom.to_string/1`. Propagates recursively to nested maps, including through lists, tuples, and unions.

  Options for `keys`/`values`:
  - `:keys` – type `t:t/0` for all keys
  - `:values` – type `t:t/0` for all values

  Both `fields` and `keys`/`values` forms support:
  - `:reject_invalid` – drop items that fail parsing instead of returning an error.
    For `fields`, only affects fields marked `optional: true` — required fields still fail.
    For `keys`/`values`, drops the key-value pair that failed.

  [Shared options](#module-shared-options) apply to all forms.

  ### Examples

      iex> Mold.parse(%{name: :string, age: :integer}, %{"name" => "Alice", "age" => "25"})
      {:ok, %{name: "Alice", age: 25}}

  Source defaults to `&Atom.to_string/1` — field names are looked up as string keys.
  Custom source per field:

      iex> schema = {:map, fields: [
      ...>   user_name: [type: :string, source: "userName"],
      ...>   is_active: [type: :boolean, source: "isActive"]
      ...> ]}
      iex> Mold.parse(schema, %{"userName" => "Alice", "isActive" => "true"})
      {:ok, %{user_name: "Alice", is_active: true}}

  Nested source paths:

      iex> schema = {:map, fields: [name: [type: :string, source: ["details", "name"]]]}
      iex> Mold.parse(schema, %{"details" => %{"name" => "Alice"}})
      {:ok, %{name: "Alice"}}

  `Access` functions for advanced navigation — `Access.at/1` for lists,
  `Access.elem/1` for tuples, `Access.key/2` with a default, and more:

      iex> schema = {:map, fields: [
      ...>   lat: [type: :float, source: ["coords", Access.at(0)]],
      ...>   lng: [type: :float, source: ["coords", Access.at(1)]]
      ...> ]}
      iex> Mold.parse(schema, %{"coords" => [49.8, 24.0]})
      {:ok, %{lat: 49.8, lng: 24.0}}

  Global source function (propagates to nested maps, lists, tuples, and unions):

      iex> schema = {
      ...>   %{user_name: :string, address: %{zip_code: :string}},
      ...>   source: &(Atom.to_string(&1) |> Macro.camelize())
      ...> }
      iex> Mold.parse(schema, %{"UserName" => "Alice", "Address" => %{"ZipCode" => "10001"}})
      {:ok, %{user_name: "Alice", address: %{zip_code: "10001"}}}

  Non-atom field names work with a custom `source`:

      iex> schema = {:map,
      ...>   source: fn {ns, name} -> Enum.join([ns, name], ":") end,
      ...>   fields: [
      ...>     {{:feature, :dark_mode}, :boolean},
      ...>     {{:feature, :beta}, :boolean}
      ...>   ]}
      iex> Mold.parse(schema, %{"feature:dark_mode" => "true", "feature:beta" => "0"})
      {:ok, %{{:feature, :dark_mode} => true, {:feature, :beta} => false}}

  Optional fields:

      iex> schema = {:map, fields: [
      ...>   name: :string,
      ...>   bio: [type: :string, optional: true]
      ...> ]}
      iex> Mold.parse(schema, %{"name" => "Alice"})
      {:ok, %{name: "Alice"}}
      iex> Mold.parse(schema, %{"name" => "Alice", "bio" => "hello"})
      {:ok, %{name: "Alice", bio: "hello"}}
      iex> # optional omits the field when missing, but nil still fails — use nilable on the type
      iex> Mold.parse(schema, %{"name" => "Alice", "bio" => nil})
      {:error, [%Mold.Error{reason: :unexpected_nil, value: nil, trace: [:bio]}]}

  When a field is both `optional: true` and has a `default`, `optional` takes priority
  for missing fields — the field is omitted from the result. The `default` only applies
  when the field is present but `nil`:

      iex> schema = {:map, fields: [
      ...>   bio: [type: {:string, default: "none"}, optional: true]
      ...> ]}
      iex> Mold.parse(schema, %{})
      {:ok, %{}}
      iex> Mold.parse(schema, %{"bio" => nil})
      {:ok, %{bio: "none"}}

  Missing fields are errors:

      iex> Mold.parse(%{name: :string}, %{})
      {:error, [%Mold.Error{reason: {:missing_field, "name"}, value: %{}, trace: [:name]}]}

  Homogeneous maps with `keys`/`values`:

      iex> Mold.parse({:map, keys: :string, values: :integer}, %{"a" => "1", "b" => "2"})
      {:ok, %{"a" => 1, "b" => 2}}

      iex> Mold.parse({:map, keys: :atom, values: :string}, %{"name" => "Alice"})
      {:ok, %{name: "Alice"}}

  Reject invalid — for `fields`, only optional fields are affected:

      iex> schema = {:map, reject_invalid: true, fields: [
      ...>   name: :string,
      ...>   age: [type: :integer, optional: true],
      ...>   bio: [type: :string, optional: true]
      ...> ]}
      iex> Mold.parse(schema, %{"name" => "Alice", "age" => "nope", "bio" => nil})
      {:ok, %{name: "Alice"}}
      iex> Mold.parse(schema, %{"age" => "25"})
      {:error, [%Mold.Error{reason: {:missing_field, "name"}, value: %{"age" => "25"}, trace: [:name]}]}

  Reject invalid — for `keys`/`values`, drops the key-value pair that failed:

      iex> Mold.parse({:map, keys: :string, values: :integer, reject_invalid: true}, %{"a" => "1", "b" => "nope"})
      {:ok, %{"a" => 1}}
  """
  @type map_type() ::
          {:map,
           fields: [
             {term(), t() | [{:type, t()} | {:source, source_path()} | {:optional, boolean()}]}
           ],
           keys: t(),
           values: t(),
           source: source_fn(),
           reject_invalid: boolean(),
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :map

  @typedoc group: "Types: Collections"
  @typedoc """
  List type. Validates each element against the given type.

  Bare `:list` validates the value is a list and returns as-is (passthrough).

  The shortcut `[type]` can always be used instead of `{:list, type: type}`,
  including with options: `{[type], opts}`.

  Options:
  - `:type` – the element type `t:t/0` (required)
  - `:source` – a function `(field_name -> any())` that propagates to the inner type
    when it contains maps. Maps with their own explicit `source` are not overridden.
  - `:reject_invalid` – drop invalid items instead of failing
  - `:min_length` – minimum list length (inclusive)
  - `:max_length` – maximum list length (inclusive)
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse([:string], ["a", "b"])
      {:ok, ["a", "b"]}

      iex> Mold.parse([%{name: :string}], [%{"name" => "A"}, %{"name" => "B"}])
      {:ok, [%{name: "A"}, %{name: "B"}]}

      iex> Mold.parse({[:integer], min_length: 1, max_length: 3}, [])
      {:error, [%Mold.Error{reason: {:too_short, min_length: 1}, value: []}]}

      iex> Mold.parse({[:string], reject_invalid: true}, ["a", nil, "b"])
      {:ok, ["a", "b"]}

      iex> Mold.parse([:integer], ["1", "abc", "3"])
      {:error, [%Mold.Error{reason: :invalid_format, value: "abc", trace: [1]}]}
  """
  @type list_type() ::
          {:list,
           type: t(),
           source: source_fn(),
           reject_invalid: boolean(),
           min_length: non_neg_integer(),
           max_length: non_neg_integer(),
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :list

  @typedoc group: "Types: Collections"
  @typedoc """
  Tuple type. Validates each element positionally. Accepts both tuples and lists as input.

  Bare `:tuple` validates the value is a tuple (or list), converts lists to tuples, returns as-is.

  Options:
  - `:elements` – list of `t:t/0`, one per element (required)
  - `:source` – a function `(field_name -> any())` that propagates to element types
    containing maps. Maps with their own explicit `source` are not overridden.
  - [Shared options](#module-shared-options)

  ### Examples

      iex> Mold.parse({:tuple, elements: [:string, :integer]}, ["Alice", "25"])
      {:ok, {"Alice", 25}}

      iex> Mold.parse({:tuple, elements: [:string, :integer]}, {"Alice", "25"})
      {:ok, {"Alice", 25}}

      iex> Mold.parse({:tuple, elements: [:string, :integer]}, ["only_one"])
      {:error, [%Mold.Error{reason: {:unexpected_length, expected: 2, got: 1}, value: ["only_one"]}]}

      iex> Mold.parse(:tuple, [1, "two", :three])
      {:ok, {1, "two", :three}}
  """
  @type tuple_type() ::
          {:tuple,
           elements: [t()],
           source: source_fn(),
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | :tuple

  @typedoc group: "Types: Custom"
  @typedoc """
  Function type. A bare `t:parse_function/0` or a tuple with [shared options](#module-shared-options).

  ### Examples

      iex> email_type = fn v ->
      ...>   if is_binary(v) and String.contains?(v, "@") do
      ...>     {:ok, String.downcase(v)}
      ...>   else
      ...>     {:error, :invalid_email}
      ...>   end
      ...> end
      iex> Mold.parse(email_type, "USER@EXAMPLE.COM")
      {:ok, "user@example.com"}
      iex> Mold.parse({email_type, nilable: true}, nil)
      {:ok, nil}
      iex> Mold.parse({email_type, default: "fallback@example.com"}, nil)
      {:ok, "fallback@example.com"}
      iex> # Use inside maps
      iex> Mold.parse(%{email: email_type}, %{"email" => "USER@EXAMPLE.COM"})
      {:ok, %{email: "user@example.com"}}
      iex> # Standard library functions work as types
      iex> Mold.parse(&JSON.decode/1, ~s|{"a": 1}|)
      {:ok, %{"a" => 1}}

  Bare `:error` is supported (see `t:parse_function/0`):

      iex> Mold.parse(&Version.parse/1, "1.0.0")
      {:ok, %Version{major: 1, minor: 0, patch: 0}}
      iex> Mold.parse(&Version.parse/1, "invalid")
      {:error, [%Mold.Error{reason: :invalid, value: "invalid"}]}
  """
  @type function_type() ::
          {parse_function(),
           nilable: boolean(),
           default: default(),
           in: Enumerable.t(),
           transform: transform(),
           validate: validate()}
          | parse_function()

  @typedoc """
  Union of all built-in and custom types accepted by `parse/2` and `parse!/2`.
  """
  @type t() ::
          string_type()
          | atom_type()
          | boolean_type()
          | integer_type()
          | float_type()
          | datetime_type()
          | naive_datetime_type()
          | date_type()
          | time_type()
          | union_type()
          | map_type()
          | list_type()
          | tuple_type()
          | function_type()
          | %{optional(any()) => t()}
          | {%{optional(any()) => t()}, keyword()}
          | [t()]
          | {[t()], keyword()}

  @doc """
  Parses `data` according to `type` or raises `t:Mold.Error.t/0` on failure.

      iex> Mold.parse!(%{name: :string}, %{"name" => "Bob"})
      %{name: "Bob"}

  Multiple errors are combined into a single exception:

      Mold.parse!(%{name: :string, age: :integer}, %{"name" => nil, "age" => "abc"})
      #=> ** (Mold.Error) Unable to parse data
      #=>
      #=> 2 errors:
      #=>   1. :unexpected_nil at [:name] (value: nil)
      #=>   2. :invalid_format at [:age] (value: "abc")
  """
  @spec parse!(t(), any()) :: any() | no_return()
  def parse!(type, data) do
    case parse(type, data) do
      {:ok, value} -> value
      {:error, errors} -> raise Mold.Error.from_many(errors)
    end
  end

  @doc """
  Parses `data` according to `type` and returns `{:ok, value}` or `{:error, [%Mold.Error{}]}`.

  See `t:t/0` for all accepted type forms, `Mold.Error` for error structure,
  and the [Formatting errors](formatting-errors.md) guide for how to present errors.

      iex> Mold.parse({:string, nilable: true, trim: true}, "  ")
      {:ok, nil}

      iex> Mold.parse(:boolean, "false")
      {:ok, false}

      iex> Mold.parse(%{name: :string}, %{})
      {:error, [%Mold.Error{reason: {:missing_field, "name"}, value: %{}, trace: [:name]}]}
  """
  @spec parse(t(), data :: any()) :: {:ok, result :: any()} | {:error, [Mold.Error.t(), ...]}
  def parse(type, data) when is_atom(type) or is_function(type, 1) do
    parse({type, []}, data)
  end

  def parse(type, data) when is_map(type) and not is_struct(type) do
    parse({:map, fields: Map.to_list(type)}, data)
  end

  def parse({type, opts}, data) when is_map(type) and not is_struct(type) do
    parse({:map, [{:fields, Map.to_list(type)} | opts]}, data)
  end

  def parse([type], data) do
    parse({:list, type: type}, data)
  end

  def parse({[type], opts}, data) do
    parse({:list, [{:type, type} | opts]}, data)
  end

  def parse({:map, opts}, data) do
    handle_shared_opts(data, opts, &is_map/1, fn data ->
      trace_acc = opts[:__trace__] || []
      reject_invalid = Keyword.get(opts, :reject_invalid, false)

      source_fn =
        case opts[:source] do
          fun when is_function(fun, 1) -> fun
          _ -> &Atom.to_string/1
        end

      case Keyword.fetch(opts, :fields) do
        {:ok, fields} ->
          {result, errors} =
            Enum.reduce(fields, {%{}, []}, fn {name, opts_or_type}, {acc, errors} ->
              has_explicit_source =
                is_list(opts_or_type) and Keyword.has_key?(opts_or_type, :type) and
                  Keyword.has_key?(opts_or_type, :source)

              opts =
                if is_list(opts_or_type) and Keyword.has_key?(opts_or_type, :type),
                  do: opts_or_type,
                  else: [type: opts_or_type, source: name]

              opts =
                if not has_explicit_source and source_fn,
                  do: Keyword.put(opts, :source, source_fn.(name)),
                  else: opts

              opts = maybe_propagate_source(opts, source_fn)
              source = List.wrap(opts[:source])

              case fetch_in(data, source) do
                {:ok, value} ->
                  trace_acc = [name | trace_acc]
                  type = put_trace_to_container_types(opts[:type], trace_acc)

                  case parse(type, value) do
                    {:ok, value} ->
                      {Map.put(acc, name, value), errors}

                    {:error, field_errors} ->
                      if reject_invalid and opts[:optional] do
                        {acc, errors}
                      else
                        field_errors = add_trace_to_errors(field_errors, trace_acc)
                        {acc, errors ++ field_errors}
                      end
                  end

                {:error, error} ->
                  if opts[:optional] do
                    {acc, errors}
                  else
                    case fetch_type_default(opts[:type]) do
                      {:ok, default} ->
                        {Map.put(acc, name, default), errors}

                      :error ->
                        {acc,
                         errors ++
                           [%{error | trace: Enum.reverse([name | trace_acc])}]}
                    end
                  end
              end
            end)

          if errors == [] do
            {:ok, result}
          else
            {:error, errors}
          end

        :error ->
          case {Keyword.fetch(opts, :keys), Keyword.fetch(opts, :values)} do
            {{:ok, key_type}, {:ok, value_type}} ->
              Enum.reduce_while(data, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
                case parse(key_type, key) do
                  {:ok, parsed_key} ->
                    key_trace_acc = [parsed_key | trace_acc]

                    case parse(put_trace_to_container_types(value_type, key_trace_acc), value) do
                      {:ok, parsed_value} ->
                        {:cont, {:ok, Map.put(acc, parsed_key, parsed_value)}}

                      {:error, errors} ->
                        if reject_invalid do
                          {:cont, {:ok, acc}}
                        else
                          {:halt, {:error, add_trace_to_errors(errors, key_trace_acc)}}
                        end
                    end

                  {:error, errors} ->
                    if reject_invalid do
                      {:cont, {:ok, acc}}
                    else
                      {:halt, {:error, add_trace_to_errors(errors, trace_acc)}}
                    end
                end
              end)

            _ ->
              {:ok, data}
          end
      end
    end)
  end

  def parse({:string, opts}, value) do
    handle_shared_opts(value, opts, &is_binary/1, fn value ->
      value =
        if Keyword.get(opts, :trim, true) do
          String.trim(value)
        else
          value
        end

      cond do
        value == "" ->
          {:ok, nil}

        opts[:format] && !Regex.match?(opts[:format], value) ->
          {:error, [Mold.Error.new(%{reason: {:invalid_format, opts[:format]}, value: value})]}

        true ->
          validate_length(value, opts, &String.length/1)
      end
    end)
  end

  def parse({:atom, opts}, value) do
    handle_shared_opts(value, opts, &(is_atom(&1) or is_binary(&1)), fn
      value when is_atom(value) ->
        {:ok, value}

      value when is_binary(value) ->
        try do
          {:ok, String.to_existing_atom(value)}
        rescue
          ArgumentError -> {:error, [Mold.Error.new(%{reason: :unknown_atom, value: value})]}
        end
    end)
  end

  def parse({:boolean, opts}, value) do
    handle_shared_opts(value, opts, &(is_boolean(&1) or is_binary(&1) or is_integer(&1)), fn
      value when is_boolean(value) ->
        {:ok, value}

      value when value in [1, "1", "true"] ->
        {:ok, true}

      value when value in [0, "0", "false"] ->
        {:ok, false}

      value when is_binary(value) or is_integer(value) ->
        {:error, [Mold.Error.new(%{reason: :invalid_format, value: value})]}
    end)
  end

  def parse({:integer, opts}, value) do
    handle_shared_opts(value, opts, &(is_integer(&1) or is_binary(&1)), fn
      value when is_integer(value) ->
        validate_number(value, opts)

      value when is_binary(value) ->
        case Integer.parse(value) do
          {integer, ""} -> validate_number(integer, opts)
          _ -> {:error, [Mold.Error.new(%{reason: :invalid_format, value: value})]}
        end
    end)
  end

  def parse({:float, opts}, value) do
    handle_shared_opts(value, opts, &(is_float(&1) or is_integer(&1) or is_binary(&1)), fn
      value when is_float(value) ->
        validate_number(value, opts)

      value when is_integer(value) ->
        validate_number(value / 1, opts)

      value when is_binary(value) ->
        case Float.parse(value) do
          {float, ""} -> validate_number(float, opts)
          _ -> {:error, [Mold.Error.new(%{reason: :invalid_format, value: value})]}
        end
    end)
  end

  def parse({:datetime, opts}, value) do
    handle_shared_opts(value, opts, &(is_binary(&1) or is_struct(&1, DateTime)), fn
      %DateTime{} = value ->
        {:ok, value}

      "" ->
        {:ok, nil}

      value ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _} -> {:ok, datetime}
          {:error, reason} -> {:error, [Mold.Error.new(%{reason: reason, value: value})]}
        end
    end)
  end

  def parse({:naive_datetime, opts}, value) do
    handle_shared_opts(value, opts, &(is_binary(&1) or is_struct(&1, NaiveDateTime)), fn
      %NaiveDateTime{} = value ->
        {:ok, value}

      "" ->
        {:ok, nil}

      value ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive_datetime} -> {:ok, naive_datetime}
          {:error, reason} -> {:error, [Mold.Error.new(%{reason: reason, value: value})]}
        end
    end)
  end

  def parse({:date, opts}, value) do
    handle_shared_opts(value, opts, &(is_binary(&1) or is_struct(&1, Date)), fn
      %Date{} = value ->
        {:ok, value}

      "" ->
        {:ok, nil}

      value ->
        case Date.from_iso8601(value) do
          {:ok, date} -> {:ok, date}
          {:error, reason} -> {:error, [Mold.Error.new(%{reason: reason, value: value})]}
        end
    end)
  end

  def parse({:tuple, opts}, value) do
    handle_shared_opts(value, opts, &(is_tuple(&1) or is_list(&1)), fn value ->
      case Keyword.fetch(opts, :elements) do
        :error ->
          value = if is_list(value), do: List.to_tuple(value), else: value
          {:ok, value}

        {:ok, elements} ->
          elements =
            case opts[:source] do
              fun when is_function(fun, 1) ->
                Enum.map(elements, &propagate_source(&1, fun))

              _ ->
                elements
            end

          list = if is_tuple(value), do: Tuple.to_list(value), else: value
          expected = length(elements)
          got = length(list)

          if expected != got do
            {:error,
             [
               Mold.Error.new(%{
                 reason: {:unexpected_length, expected: expected, got: got},
                 value: value
               })
             ]}
          else
            trace_acc = opts[:__trace__] || []

            {result, errors} =
              elements
              |> Enum.zip(list)
              |> Enum.with_index()
              |> Enum.reduce({[], []}, fn {{type, val}, index}, {acc, errors} ->
                trace_acc = [index | trace_acc]
                type = put_trace_to_container_types(type, trace_acc)

                case parse(type, val) do
                  {:ok, val} ->
                    {[val | acc], errors}

                  {:error, el_errors} ->
                    {acc, errors ++ add_trace_to_errors(el_errors, trace_acc)}
                end
              end)

            if errors == [] do
              {:ok, result |> Enum.reverse() |> List.to_tuple()}
            else
              {:error, errors}
            end
          end
      end
    end)
  end

  def parse({:time, opts}, value) do
    handle_shared_opts(value, opts, &(is_binary(&1) or is_struct(&1, Time)), fn
      %Time{} = value ->
        {:ok, value}

      "" ->
        {:ok, nil}

      value ->
        case Time.from_iso8601(value) do
          {:ok, time} -> {:ok, time}
          {:error, reason} -> {:error, [Mold.Error.new(%{reason: reason, value: value})]}
        end
    end)
  end

  def parse({parse_fn, opts}, value) when is_function(parse_fn, 1) do
    handle_shared_opts(value, opts, fn _ -> true end, fn value ->
      case parse_fn.(value) do
        {:ok, _} = result ->
          result

        {:error, [%Mold.Error{} | _] = errors} ->
          {:error, prepend_trace(errors, opts[:__trace__])}

        {:error, reason} ->
          {:error, [Mold.Error.new(%{reason: reason, value: value})]}

        :error ->
          {:error, [Mold.Error.new(%{reason: :invalid, value: value})]}

        _ ->
          raise ArgumentError,
                "Invalid parse function result, expected {:ok, value} or {:error, reason}"
      end
    end)
  end

  def parse({:union, opts}, value) do
    handle_shared_opts(value, opts, fn _ -> true end, fn value ->
      by = Keyword.fetch!(opts, :by)
      of = Keyword.fetch!(opts, :of)

      of =
        case opts[:source] do
          fun when is_function(fun, 1) ->
            Map.new(of, fn {key, type} -> {key, propagate_source(type, fun)} end)

          _ ->
            of
        end

      key = by.(value)

      case Map.fetch(of, key) do
        {:ok, type} -> parse(type, value)
        :error -> {:error, [Mold.Error.new(%{reason: {:unknown_variant, key}, value: value})]}
      end
    end)
  end

  def parse({:list, opts}, value) do
    handle_shared_opts(value, opts, &is_list/1, fn value ->
      case Keyword.fetch(opts, :type) do
        {:ok, type} ->
          type =
            case opts[:source] do
              fun when is_function(fun, 1) -> propagate_source(type, fun)
              _ -> type
            end

          reject_invalid = Keyword.get(opts, :reject_invalid, false)
          trace_acc = opts[:__trace__] || []

          result =
            value
            |> Enum.with_index()
            |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
              trace_acc = [index | trace_acc]
              type = put_trace_to_container_types(type, trace_acc)

              case parse(type, value) do
                {:ok, value} ->
                  {:cont, {:ok, [value | acc]}}

                {:error, errors} ->
                  if reject_invalid do
                    {:cont, {:ok, acc}}
                  else
                    {:halt, {:error, add_trace_to_errors(errors, trace_acc)}}
                  end
              end
            end)

          with {:ok, values} <- result do
            values = Enum.reverse(values)
            validate_length(values, opts, &length/1)
          end

        :error ->
          {:ok, value}
      end
    end)
  end

  defp apply_transform(value, opts) do
    case Keyword.fetch(opts, :transform) do
      {:ok, fun} when is_function(fun, 1) -> fun.(value)
      :error -> value
    end
  end

  defp apply_validate(value, opts) do
    case Keyword.fetch(opts, :validate) do
      {:ok, fun} when is_function(fun, 1) ->
        if fun.(value),
          do: {:ok, value},
          else: {:error, [Mold.Error.new(%{reason: :validation_failed, value: value})]}

      :error ->
        {:ok, value}
    end
  end

  defp validate_in(value, opts) do
    case Keyword.fetch(opts, :in) do
      {:ok, allowed} ->
        if value in allowed,
          do: {:ok, value},
          else: {:error, [Mold.Error.new(%{reason: {:not_in, allowed}, value: value})]}

      :error ->
        {:ok, value}
    end
  end

  defp validate_number(value, opts) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)

    cond do
      min != nil and value < min ->
        {:error, [Mold.Error.new(%{reason: {:too_small, min: min}, value: value})]}

      max != nil and value > max ->
        {:error, [Mold.Error.new(%{reason: {:too_large, max: max}, value: value})]}

      true ->
        {:ok, value}
    end
  end

  defp validate_length(value, opts, length_fun) do
    min = Keyword.get(opts, :min_length)
    max = Keyword.get(opts, :max_length)

    if min != nil or max != nil do
      len = length_fun.(value)

      cond do
        min != nil and len < min ->
          {:error, [Mold.Error.new(%{reason: {:too_short, min_length: min}, value: value})]}

        max != nil and len > max ->
          {:error, [Mold.Error.new(%{reason: {:too_long, max_length: max}, value: value})]}

        true ->
          {:ok, value}
      end
    else
      {:ok, value}
    end
  end

  defp fetch_in(data, path) do
    result =
      Enum.reduce_while(path, {:ok, {[], data}}, fn step, {:ok, {trace, acc}} ->
        case fetch_in_step(acc, step) do
          {:ok, value} ->
            {:cont, {:ok, {trace ++ [step], value}}}

          {:error, reason} ->
            {:halt, {:error, Mold.Error.new(%{reason: reason, value: acc, trace: trace})}}
        end
      end)

    with {:ok, {_trace, data}} <- result do
      {:ok, data}
    end
  end

  defp fetch_in_step(data, accessor) when is_function(accessor) do
    {:ok, accessor.(:get, data, & &1)}
  rescue
    _ -> {:error, :unexpected_type}
  end

  defp fetch_in_step(data, key) when is_map(data) or is_list(data) do
    case Access.fetch(data, key) do
      {:ok, _} = ok -> ok
      :error -> {:error, {:missing_field, key}}
    end
  end

  defp fetch_in_step(_data, _key) do
    {:error, :unexpected_type}
  end

  defp maybe_propagate_source(field_opts, source_fn) do
    Keyword.update!(field_opts, :type, fn type -> propagate_source(type, source_fn) end)
  end

  defp propagate_source({:map, opts}, source_fn) do
    case opts[:source] do
      fun when is_function(fun, 1) -> {:map, opts}
      _ -> {:map, Keyword.put(opts, :source, source_fn)}
    end
  end

  defp propagate_source({:list, opts}, source_fn) do
    {:list, Keyword.update!(opts, :type, &propagate_source(&1, source_fn))}
  end

  defp propagate_source(type, source_fn) when is_map(type) and not is_struct(type) do
    {:map, [fields: Map.to_list(type), source: source_fn]}
  end

  defp propagate_source({type, opts}, source_fn) when is_map(type) and not is_struct(type) do
    {:map, [{:fields, Map.to_list(type)}, {:source, source_fn} | opts]}
  end

  defp propagate_source([inner_type], source_fn) do
    {:list, [type: propagate_source(inner_type, source_fn)]}
  end

  defp propagate_source({[inner_type], opts}, source_fn) do
    {:list, [{:type, propagate_source(inner_type, source_fn)} | opts]}
  end

  defp propagate_source({:tuple, opts}, source_fn) do
    {:tuple,
     Keyword.update!(opts, :elements, fn elements ->
       Enum.map(elements, &propagate_source(&1, source_fn))
     end)}
  end

  defp propagate_source({:union, opts}, source_fn) do
    {:union,
     Keyword.update!(opts, :of, fn of ->
       Map.new(of, fn {key, type} -> {key, propagate_source(type, source_fn)} end)
     end)}
  end

  defp propagate_source(type, _source_fn), do: type

  defp put_trace_to_container_types({type_name, opts}, trace)
       when type_name in [:map, :list, :tuple] do
    {type_name, Keyword.put(opts, :__trace__, trace)}
  end

  defp put_trace_to_container_types(type, trace) when is_map(type) and not is_struct(type) do
    {:map, [fields: Map.to_list(type), __trace__: trace]}
  end

  defp put_trace_to_container_types(fun, trace) when is_function(fun, 1) do
    {fun, __trace__: trace}
  end

  defp put_trace_to_container_types({fun, opts}, trace) when is_function(fun, 1) do
    {fun, Keyword.put(opts, :__trace__, trace)}
  end

  defp put_trace_to_container_types(type, _trace) do
    type
  end

  defp handle_shared_opts(value, opts, type_validator, parse_fn) do
    cond do
      is_nil(value) ->
        handle_nil_value(value, opts)

      type_validator.(value) ->
        case parse_fn.(value) do
          {:ok, nil} ->
            handle_nil_value(value, opts)

          {:ok, value} ->
            value = apply_transform(value, opts)

            with {:ok, value} <- validate_in(value, opts) do
              apply_validate(value, opts)
            end

          {:error, errors} ->
            {:error, errors}
        end

      true ->
        {:error, [Mold.Error.new(%{reason: :unexpected_type, value: value})]}
    end
  end

  defp add_trace_to_errors(errors, trace_acc) do
    trace = Enum.reverse(trace_acc)

    Enum.map(errors, fn
      %Mold.Error{trace: nil} = error -> %{error | trace: trace}
      error -> error
    end)
  end

  defp prepend_trace(errors, nil), do: errors

  defp prepend_trace(errors, trace_acc) do
    trace = Enum.reverse(trace_acc)

    Enum.map(errors, fn
      %Mold.Error{trace: nil} = error -> %{error | trace: trace}
      %Mold.Error{trace: existing} = error -> %{error | trace: trace ++ existing}
    end)
  end

  defp fetch_type_default({_type, opts}) when is_list(opts) do
    case Keyword.fetch(opts, :default) do
      {:ok, default} -> {:ok, resolve_default(default)}
      :error -> :error
    end
  end

  defp fetch_type_default(_), do: :error

  defp handle_nil_value(value, opts) do
    cond do
      Keyword.get(opts, :nilable, false) -> {:ok, nil}
      Keyword.has_key?(opts, :default) -> {:ok, resolve_default(opts[:default])}
      true -> {:error, [Mold.Error.new(%{reason: :unexpected_nil, value: value})]}
    end
  end

  defp resolve_default(fun) when is_function(fun, 0), do: fun.()

  defp resolve_default({mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args),
    do: apply(mod, fun, args)

  defp resolve_default(value), do: value
end
