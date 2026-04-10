defmodule Mold.Error do
  @moduledoc """
  Exception raised/returned by Mold when parsing fails.

  ## Fields

  - `:reason` – atom or term explaining the failure (see Reasons below).
  - `:value` – the offending value.
  - `:trace` – path to the failing value (schema field names, list indexes, and/or dynamic map keys), or `nil`.

  ## Reasons

  ### Shared (all types)

  | Reason | When |
  |---|---|
  | `:unexpected_nil` | Value is `nil` (or empty string for `:string`/date-time types) and type is not nilable |
  | `:unexpected_type` | Value doesn't match expected input type (e.g. passing a list to `:string`) |
  | `{:not_in, enumerable}` | Parsed value not in the `:in` set |
  | `:validation_failed` | Custom `:validate` function returned `false` |

  ### String

  | Reason | When |
  |---|---|
  | `{:invalid_format, regex}` | Value doesn't match the `:format` regex |
  | `{:too_short, min_length: n}` | String shorter than `:min_length` |
  | `{:too_long, max_length: n}` | String longer than `:max_length` |

  ### Integer / Float

  | Reason | When |
  |---|---|
  | `:invalid_format` | Can't parse as number |
  | `{:too_small, min: n}` | Below `:min` |
  | `{:too_large, max: n}` | Above `:max` |

  ### Boolean

  | Reason | When |
  |---|---|
  | `:invalid_format` | Not a recognized boolean value |

  ### Atom

  | Reason | When |
  |---|---|
  | `:unknown_atom` | String doesn't correspond to an existing atom |

  ### Date & Time

  Reasons are passed through from Elixir's standard library parsers
  (`Date.from_iso8601/1`, `DateTime.from_iso8601/1`, etc.):

  | Reason | When |
  |---|---|
  | `:invalid_format` | Not a valid ISO8601 string |
  | `:invalid_date` | Valid format but invalid date (e.g. month 13) |
  | `:invalid_time` | Valid format but invalid time (e.g. hour 25) |
  | `:missing_offset` | DateTime string missing timezone offset |

  ### Map

  | Reason | When |
  |---|---|
  | `{:missing_field, key}` | Required field not found in input |

  ### List

  | Reason | When |
  |---|---|
  | `{:too_short, min_length: n}` | List shorter than `:min_length` |
  | `{:too_long, max_length: n}` | List longer than `:max_length` |

  ### Tuple

  | Reason | When |
  |---|---|
  | `{:unexpected_length, expected: n, got: n}` | Wrong number of elements |

  ### Union

  | Reason | When |
  |---|---|
  | `{:unknown_variant, key}` | `:by` function returned a key not in `:of` |

  ### Custom function

  | Reason | When |
  |---|---|
  | `:invalid` | Function returned bare `:error` |
  | *any term* | Passed through from `{:error, reason}` |
  """
  @type t :: %__MODULE__{reason: any(), value: any(), trace: [any()] | nil}
  defexception [:reason, :value, :trace]

  @doc false
  def new(data) do
    %__MODULE__{
      reason: data.reason,
      value: data.value,
      trace: data[:trace]
    }
  end

  @impl true
  def message(%__MODULE__{reason: {:multiple, errors}}) do
    details =
      errors
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {error, i} -> "  #{i}. #{format_one(error)}" end)

    "Unable to parse data\n\n#{length(errors)} errors:\n#{details}\n"
  end

  def message(%__MODULE__{} = error) do
    "Unable to parse data\n\n#{format_one(error)}\n"
  end

  @doc false
  def from_many([error]), do: error
  def from_many(errors), do: %__MODULE__{reason: {:multiple, errors}, value: nil, trace: nil}

  defp format_one(error) do
    trace_part = if error.trace, do: " at #{inspect(error.trace)}", else: ""
    "#{inspect(error.reason)}#{trace_part} (value: #{inspect(error.value)})"
  end
end
