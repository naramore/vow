# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- [codecov.io] support to CI
- readme badges for hex version, github actions status, and codecov
- credo default config file
- dependabot badge
- more tests!
- implemented `Vow.Keys`
- `Vow.Conformable.unform/2`, `Vow.unform/2`, & `Vow.unform!/2`
- `Vow.Generatable` for all `Vow.Conformable`
- `Vow.get_in/2` & `Vow.{put|update}_in/3` w/ 'lazy' paths
- `Access` behaviour to 'all' `Vow.Conformable` (some are intentionally not implemented b/c it doesn't make sense, e.g. `Vow.FunctionWrapper`)
- `Acs`, a.k.a. 'lazy' `Access`, will auto-wrap integer and atom keys in `Access.{at, elem, key}/1` and return non-errors if path is invalid
- `StreamDataUtils` which has a bunch of generators I wish `StreamData` had
- `Vow.Utils` and consolidated all the 'utility' functions that were lying around in random places
- `Vow.Utils.AccessShortcut.__using__/1` which auto-implements 3 common Access patterns for my `Vow` structs
- `Vow.WithGen` to wrap any other vow and bind it to a specified generator function to enable more optimized data generation

### Changed
- `Vow.Func.f/1` -> `Vow.FunctionWrapper.wrap/1`
- coveralls config to ignore wrap macro for coverage purposes
- all 'named' references of `spec` to `vow`
- `Vow.FunctionWrapper` to allow optional variable bindings for pretty printing
- `Vow.Conformable.Map` to allow for keys not specified in the specification, similar to pattern matching
- re-organized all errors into the vow/error.ex file, including vow/conform_error.ex
- moved some of the date/time-related generators in test/support/vow_data.ex to test/support/stream_data_utils.ex

### Removed
- `merge_fun` option from `Vow.merge/2` b/c it made conforming difficult (impossible?) to unform

## [0.0.2] - 2019-10-23
### Added
- release documentation so I don't forget

### Fixed
- changelog, mix.exs, and readme links
- `Vow.ConformError` is `@moduledoc false` now

### Removed
- replaced my `use` macros per Elixir's [Library Guidelines - Anit-Patterns] with imports

## [0.0.1] - 2019-10-23
### Added
- `Vow.Conformable` protocol (a.k.a. the core of this library's ability to validate data)
- `Vow.RegexOperator` protocol (used for enumerable/list-based specs)
- tests for 'non-compound' specs (i.e. specs that don't contain specs)
- CI automation via GitHub Actions
- changed name from `ExSpec` to `Vow` (as the former was already taken)


[codecov.io]: https://codecov.io/
[Library Guidelines - Anti-Patterns]: https://hexdocs.pm/elixir/library-guidelines.html#avoid-use-when-an-import-is-enough
[Unreleased]: https://github.com/naramore/vow/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/naramore/vow/releases/tag/v0.0.1...v0.0.2
[0.0.1]: https://github.com/naramore/vow/releases/tag/v0.0.1
