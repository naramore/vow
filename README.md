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

## TODO

- [ ] documentation
- [ ] tests
  - [ ] `Vow.Conformable.unform/2`
  - [ ] `Vow.Generatable.gen/1`
  - [ ] `Vow.*.{fetch/2, get_and_update_in/2, pop/2}`
  - [ ] `Vow.get_in/2` & `Vow.{update, pop}_in/3`
- [ ] test for nested lists conforming with expected behavior... (especially the regex operators)
- [ ] add many *specific* compound vow examples (look at `clojure.spec` docs / guides for inspiration)
- [ ] add caching for github actions (e.g. dialyzer, deps.get), once available
  - [ ] and re-add dialyzer back to the action
- [ ] 'figure out' inch-ci via `inch_ex`
- [ ] implement `Vow.Generatable.gen/1` & `Access` for `Vow.Keys`
