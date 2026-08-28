# Changelog

## [Unreleased]

## [0.3.0] - 2026-08-28

### Changed

- Lists now collect all element errors instead of stopping at the first one, consistent with maps and tuples.
- `:integer`, `:float`, `:boolean`, and `:atom` now treat empty strings as `nil`, like `:string` and the date/time types already did. This makes `nilable` and `default` work for these types when the input is `""`, and changes the error reason from `:invalid_format` to `:unexpected_nil` when neither option is set.

### Fixed

- `:atom` no longer accepts an empty string as the atom `:""`. Since `:""` always exists at runtime, `String.to_existing_atom("")` never raised and the empty value passed validation silently.
- Optional fields and fields with defaults no longer hide `:unexpected_type` errors caused by malformed intermediate values in a `source` path. Only missing path segments trigger omission or a default.
- Errors returned by nested union variants now preserve the full outer trace.

### Documentation

- Custom function types now document that a bare capture such as `&Version.parse/1` raises on input of an unexpected shape, and show the guard clause that returns `{:error, :unexpected_type}` instead.
- Documented empty-string handling, the full `validate` return contract, and that defaults are final values which skip parsing and the shared option pipeline.
- Completed the error-formatting example for all built-in reasons and corrected the nested trace example in the README.

## [0.2.0] - 2026-04-19

### Added

- `source` option for `:union`, `:list`, and `:tuple` types.
- `validate` functions can now return `:ok`, `:error`, or `{:error, reason}` in addition to `true`/`false`. `{:error, reason}` allows custom error reasons; `:ok`/`:error` mirror `true`/`false`.

### Changed

- Dynamic maps (`keys`/`values`) now collect all entry errors instead of stopping at the first one, consistent with how `fields` behave.

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

[Unreleased]: https://github.com/fuelen/mold/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/fuelen/mold/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/fuelen/mold/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/fuelen/mold/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/fuelen/mold/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/fuelen/mold/releases/tag/v0.1.0
