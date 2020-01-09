**CHANGING RAPIDLY, USE AT YOUR OWN RISK**

# Vow

[![Latest Version](https://img.shields.io/hexpm/v/vow.svg?maxAge=3600)](https://hex.pm/packages/vow)
[![Actions Status](https://github.com/naramore/vow/workflows/ElixirCI/badge.svg)](https://github.com/naramore/vow/actions)
[![codecov](https://codecov.io/gh/naramore/vow/branch/master/graph/badge.svg?token=)](https://codecov.io/gh/naramore/vow)
[![Dependabot](https://api.dependabot.com/badges/status?host=github&repo=naramore/vow)](https://dependabot.com)

Vow is a data specification library inspired by [clojure.spec](https://clojure.org/guides/spec).

Documentation, examples, and tutorials can be found at https://hexdocs.pm/vow.

## Installation

[Available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vow` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:vow, "~> 0.0.2"}]
end
```

## Rationale and Overview

## Features

## Glossery

## Roadmap

- [ ] investigate 'better' default generators for `Vow.{Also, Amp, Merge, Function, Regex, Pat}`
- [ ] add elixir `1.10` to CI (once out of rc)
- [ ] investigate `Vow.RegexOperator` refactor to support `Enumerable` instead of `List`
- [ ] examples folder + hook into tests?
- [ ] v0.1.0
  - [ ] more tests!
    - [ ] re-evaluate the test coverage threshold in `coveralls.json`
    - [ ] `test/support/mock.ex` -> `Vow.Mock` & `Vow.Mock.Regex`
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
  - [ ] remove the warning from the readme
  - [ ] documentation refactoring pass
  - [ ] test refactoring pass
  - [ ] examples refactoring pass
  - [ ] implementation refactoring pass
- [ ] v0.0.3 (pre-release)
  - [ ] re-evaluate all instances of `# credo:disable-for-` in the code-base
  - [ ] implement `Vow.Generatable.gen/2` for `Vow.Keys`
  - [ ] investigate `Vow.Conformable.Vow.Keys.conform_impl/4` (specifically how `required?` is used...)
  - [ ] investigate `Vow.Keys` expression traversal (i.e. generalize `Vow.Keys.{check_keys, update_keys, find_key}` & `Vow.Conformable.Vow.Keys.{conform_impl, unform_impl}`)
  - [ ] more credo rules + refactoring
  - [x] `ExPat` integration?
  - [ ] documentation examples pass (+ doctest verification)
  - [ ] documentation
    - [ ] README.md
    - [x] `Vow`
    - [ ] `Vow.Conformable`
    - [ ] `Vow.ConformError`
    - [x] `Vow.FunctionWrapper`
    - [x] `Vow.Function`
    - [x] `Vow.Generatable`
    - [ ] `Vow.RegexOperator`
    - [ ] `StreamDataUtils`
    - [x] `Acs`
