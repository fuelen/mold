# Changelog

## [Unreleased]

### Added

- `source` option for `:union`, `:list`, and `:tuple` types.
- `validate` functions can now return `:ok`, `:error`, or `{:error, reason}` in addition to `true`/`false`. `{:error, reason}` allows custom error reasons; `:ok`/`:error` mirror `true`/`false`.

### Documentation

- New guide: using Mold with HTTP clients.
- New guide: formatting errors.
- Trace examples in README and `parse!/2` docstring now use atoms instead of strings.

## [0.1.2] - 2026-04-10

### Fixed

- Error trace now uses schema field names (atoms like `[:address, :city]`) instead of raw source keys (strings like `["address", "city"]`) or opaque Access function references (`[#Function<...>]`).
- Dynamic map trace: key parse errors no longer include the unparsed key in the trace; value errors use the parsed key.

### Changed

- Trace building now uses prepend + reverse internally instead of append.

## [0.1.1] - 2026-04-10

### Fixed

- `nilable: true` combined with `default` no longer replaces an explicit `nil` with the default value. The default now only applies to missing fields.
- Documentation updated to reflect the corrected `nilable` + `default` interaction.

## [0.1.0] - 2026-04-06

Initial release.

### Added

- `Mold.parse/2` and `Mold.parse!/2`.
- Built-in types: `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:date`, `:datetime`, `:naive_datetime`, `:time`.
- Collections: `:map` (fields and homogeneous), `:list`, `:tuple`.
- Union types, custom parse functions, recursive types.
- Shared options: `nilable`, `default`, `in`, `transform`, `validate`.
- Source key mapping with propagation to nested structures.
- Rich error traces with path to the failing value.

[Unreleased]: https://github.com/fuelen/mold/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/fuelen/mold/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/fuelen/mold/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/fuelen/mold/releases/tag/v0.1.0
