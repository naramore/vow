# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- [codecov.io] support to CI
- documentation coverage analysis via [doctor] to CI
- documentation improvement analytics via [inch_ex] to CI
- readme badges for hex version, github actions status, and codecov
- credo default config file
- dependabot badge
- more tests!

### Changed
- `Vow.Func.f/1` -> `Vow.FunctionWrapper.wrap/1`
- coveralls config to ignore wrap macro for coverage purposes
- all 'named' references of `spec` to `vow`

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


[doctor]: https://github.com/akoutmos/doctor
[inch_ex]: https://hex.pm/packages/inch_ex
[codecov.io]: https://codecov.io/
[Library Guidelines - Anti-Patterns]: https://hexdocs.pm/elixir/library-guidelines.html#avoid-use-when-an-import-is-enough
[Unreleased]: https://github.com/naramore/vow/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/naramore/vow/releases/tag/v0.0.1...v0.0.2
[0.0.1]: https://github.com/naramore/vow/releases/tag/v0.0.1
