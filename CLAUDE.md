# Mold Project Instructions

Mold is a tiny, zero-dependency parsing library for external payloads (JSON APIs, webhooks, HTTP params).
Main API: `Mold.parse/2`, `Mold.parse!/2`. Types are plain data (atoms, tuples, maps, lists, functions).

## Tests
- Structure: `describe "parse!/2"`, `describe "parse/2"` with one test per type inside
- Don't rename variables during test refactoring — Elixir allows rebinding, reuse `schema` freely
- Prefer shortcut syntax in schemas: `%{name: :string}` over `{:map, fields: [name: :string]}`, `[:string]` over `{:list, type: :string}`. Use the long form only when container-level options are needed (e.g. `{:map, source: ..., fields: [...]}`)
- Before committing, verify the diff: compare assertion counts and check nothing was lost or added unintentionally

## Code
- When refactoring documentation, don't remove options from typespecs — typespecs must always reflect all accepted options
- Always run `mix format` before committing

## Benchmarks
- Use reasonable iteration counts (10K-100K), not 1M+
