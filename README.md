**CHANGING RAPIDLY, USE AT YOUR OWN RISK**

# Vow

[![Latest Version](https://img.shields.io/hexpm/v/vow.svg?maxAge=3600)](https://hex.pm/packages/vow)
[![Actions Status](https://github.com/naramore/vow/workflows/ElixirCI/badge.svg)](https://github.com/naramore/vow/actions)
[![codecov](https://codecov.io/gh/naramore/vow/branch/master/graph/badge.svg?token=)](https://codecov.io/gh/naramore/vow)
[![Dependabot](https://api.dependabot.com/badges/status?host=github&repo=naramore/vow)](https://dependabot.com)

Vow is a data specification library inspired by [clojure.spec](https://clojure.org/guides/spec).

Documentation, examples, and how tos can be found at https://hexdocs.pm/vow.

## Installation

[Available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vow` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:vow, "~> 0.0.2"}]
end
```

## Roadmap

- [ ] v0.1.0
  - [ ] documentation
    - [ ] README.md
    - [ ] `Vow`
    - [ ] `Vow.Conformable`
    - [ ] `Vow.FunctionWrapper`
    - [ ] `Vow.Function`
    - [ ] `Vow.Generatable`
    - [ ] `Vow.RegexOperator`
    - [ ] `StreamDataUtils`
    - [ ] `Acs`
- [ ] v0.0.5 (pre-release)
  - [ ] investigate the ignored dialyzer warnings for refactoring opportunities
  - [ ] more credo rules + refactoring
    - [ ] refactor all paths to be 'backwards', and reverse them on problem creation?
  - [ ] replace all instances of `value` w/ `val`?
  - [ ] add `mix doctor` to CI
  - [ ] refactor CI to be `test` (matrix w/ compile, test, dialyzer, credo) and `check` (format, report, doctor, xref)
- [ ] v0.0.4 (pre-release)
  - [ ] more tests!
    - [ ] `Vow.Conformable.**.unform/2`
    - [ ] `Vow.Generatable.**.gen/1`
    - [ ] `Vow.*.{fetch/2, get_and_update_in/2, pop/2}`
    - [ ] `Acs.{get, pop}_in/2` & `Vow.{update, put, get_and_update}_in/3`
    - [ ] `Vow.Function.conform/3`
    - [ ] `Vow.WithGen` <- `Vow.{Conformable, Generatable, RegexOperator}`
    - [ ] `StreamDataUtils`
      - [ ] `simple/0`
      - [ ] `function/2`
      - [ ] `lazy/1`
      - [ ] `struct/2`
      - [ ] `tuple_of/2`
      - [ ] `atom/0`
      - [ ] `non_neg_integer/0`
      - [ ] `neg_integer/0`
      - [ ] `keyword_of/2`
      - [ ] `datetime/1`
      - [ ] `date_range/1`
      - [ ] `date/1`
      - [ ] `time/1`
      - [ ] `range/0` & `range/1`
  - [ ] test for nested lists conforming with expected behavior... (especially the regex operators)
  - [ ] add many *specific* compound vow examples (look at `clojure.spec` docs / guides for inspiration)
- [ ] v0.0.3 (pre-release)
  - [ ] implement `Vow.Generatable.gen/2` for `Vow.Keys`
  - [ ] re-implement `Access` for `Vow.Map` to not 'passthrough' and instead be key-based on `key_vow | value_vow`
  - [ ] remove 'multi-passthrough' implementation of `Access` for `Vow.{Alt, Amp, Merge}`
    - [ ] decide whether to use index-based access (as the current implementation of these involve lists)
      - this could be infuriatingly undescriptive (i.e. just an integer)
    - [x] or key-based access (now requiring 'union'-based vows to name their sub-vows like cat|alt|one_of)
      - this could be 'confusing' as the names are used in conforming for alt|cat|one_of, whereas they would not be for
    - [ ] or all at once (what is 'implemented' now)
