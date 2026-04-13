# Formatting errors

Mold does not include a built-in error formatter. This is a deliberate choice, not a missing feature.

## Why no built-in formatter?

The `:reason` field of `Mold.Error` is typed as `any()` because custom parse functions can return
any term as an error reason: an atom, a string, an Ecto changeset, or an arbitrary struct. There are
not that many built-in reasons (see `Mold.Error`), so mapping them to messages is trivial.
Adding a built-in formatter would not save much code, and it would need a callback for custom
reasons, making the API more complex than just writing the mapping yourself.

Error formatting is also a presentation concern. A REST API, a GraphQL endpoint, a CLI tool,
and a LiveView form each need a different format. An internationalized app needs error messages
in the user's language. Mold's job ends at producing structured error data (`reason`, `value`,
and `trace`), so your application has full control over how to present it.

Some applications may want to present errors as a nested tree (mirroring the input structure)
rather than a flat list. This is straightforward to build from the `:trace` field, but is
a presentation decision that Mold leaves to you.

## Basic example

A simple module that maps reasons to messages:

```elixir
defmodule MyApp.MoldErrorFormatter do
  def message(%Mold.Error{} = error) do
    format_reason(error.reason)
  end

  # Built-in reasons
  defp format_reason(:unexpected_nil), do: "is required"
  defp format_reason(:unexpected_type), do: "has invalid type"
  defp format_reason(:invalid_format), do: "has invalid format"
  defp format_reason({:invalid_format, _}), do: "has invalid format"
  defp format_reason(:validation_failed), do: "is invalid"
  defp format_reason(:invalid), do: "is invalid"
  defp format_reason({:missing_field, _}), do: "is required"
  defp format_reason({:too_small, min: min}), do: "must be at least #{min}"
  defp format_reason({:too_large, max: max}), do: "must be at most #{max}"
  defp format_reason({:too_short, min_length: n}), do: "length must be at least #{n}"
  defp format_reason({:too_long, max_length: n}), do: "length must be at most #{n}"
  defp format_reason({:not_in, _}), do: "is not an accepted value"
  # Catch-all for custom parse function reasons.
  # A safe default that avoids leaking internal data to the end user.
  # Add clauses above for any custom reasons you want to display.
  defp format_reason(_reason), do: "is invalid"
end
```

Use it in a Phoenix fallback controller:

```elixir
def call(conn, {:error, [%Mold.Error{} | _] = errors}) do
  conn
  |> put_status(:unprocessable_entity)
  |> json(%{
    errors:
      Enum.map(errors, fn error ->
        %{message: MyApp.MoldErrorFormatter.message(error), trace: error.trace}
      end)
  })
end
```

This is enough for most cases. As the application grows and errors come from different sources
(Mold, Ecto, custom domain logic), the fallback controller starts accumulating clauses for each
error shape. At that point, consider extracting the per-error formatting and the response assembly
into protocols so each error source has its own implementation behind a unified interface, and
the controller stays a single clause. That's a general application architecture concern, not
specific to Mold, but `Mold.Error` slots into such a design like any other error struct.
