# Using with HTTP clients

Mold often parses bodies of HTTP responses. This guide shows how to move that parsing
inside the HTTP client pipeline, so that the call site reads as a declarative contract
and your APM dashboards stop lying about failures.

## Why parse inside the HTTP pipeline

Parsing inside the HTTP pipeline turns the expected response into a **declarative
contract** with the remote service. At the call site the client code says which
status codes are acceptable and what shape their body should have:

```elixir
mold: %{200 => user_schema(), 404 => nil}
```

Anybody reading this sees the contract at a glance: "200 with this shape is fine;
404 is fine too (we don't care what's in the body); anything else is a bug." The
pipeline uses that to decide what counts as a successful request from the
application's point of view.

The alternative, parsing after the call, makes the HTTP client lie about success:

- A `500` response looks like a successful request to the HTTP client. Telemetry
  records it that way, and the error surfaces later, detached from the request that
  caused it.
- A `200` whose body doesn't match the schema passes the same check unchallenged.
  The schema mismatch surfaces later, disconnected from the telemetry event of the
  request that caused it.
- A `404` can be a normal answer ("the resource isn't there, return `nil`") or a bug
  ("our URL pointed at something that shouldn't exist, alert me"). Which interpretation
  applies is a per-function decision: including or omitting `404` from the schema map
  tells the pipeline which one you mean.

When parsing runs inside the pipeline, all three cases become failures of the HTTP
request itself: they appear in the same telemetry event, the same logs, the same error
plumbing as network errors and timeouts.

This is the side of the pattern that pays off the most in practice. Schema mismatches
and unexpected statuses show up on the same APM dashboards (DataDog, New Relic, and
similar) as timeouts and connection errors, right next to them, with no
integration-specific code. Without parsing inside the pipeline, everything you want
to see on those dashboards is extra code on your side: custom telemetry events,
hand-written structured logs, per-call alerting. And until that code exists, the
dashboards report these failures as successful requests.

## The contract

The pipeline reads one option per call: a map from HTTP status code to a Mold schema
or `nil`.

```elixir
mold: %{status_code => schema_or_nil, ...}
```

Rules:

| Case | Result |
|---|---|
| Status is **not** in the map | Request fails: unexpected status |
| Status is in the map, schema is `nil` | Accept the response as-is, don't parse the body |
| Status is in the map, schema is a Mold type | `Mold.parse(schema, body)`; on success replace `body` with the parsed result |
| `Mold.parse/2` returns errors | Request fails: schema mismatch |

`nil` is useful for `204 No Content`, for statuses where the caller only cares about
presence or absence (like `404`), and for any response whose body you don't want parsed
at all, such as a binary download, a stream, or a redirect.

## Implementations

For Tesla, the [tesla_middleware_mold](https://hexdocs.pm/tesla_middleware_mold)
package implements this pattern. See its docs for installation, usage examples, and
error details.

For other clients that expose a pluggable response pipeline (Req, custom wrappers),
write a response step that:

- reads the mold option from the request (the exact key depends on the client)
- looks up the response status in the schema map
- passes the body through `Mold.parse/2` when the schema is a Mold type
- fails the request with a reason that describes the mismatch

Place the step after the client's telemetry instrumentation (so failures land in the
request's telemetry event) and after body decoding (so the step sees the decoded
value, not a raw JSON string). The
[tesla_middleware_mold source](https://github.com/fuelen/tesla_middleware_mold/blob/main/lib/tesla/middleware/mold.ex)
can serve as a reference implementation.

For turning `%Mold.Error{}` structs into user-visible messages, see
[Formatting errors](formatting-errors.md).
