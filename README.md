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
- [ ] test for nested lists conforming with expected behavior... (especially the regex operators)
- [ ] add many *specific* compound vow examples (look at `clojure.spec` docs / guides for inspiration)
- [ ] add caching for github actions (e.g. dialyzer, deps.get), once available
- [ ] implement `Vow.Keys` (+ accept any keys not specified as required or optional, but don't conform them...obviously)
- [ ] implement `Vow.Generatable` for all `Vow.Conformable`'s
- [ ] add `unform` to the `Vow.Conformable` (and `Vow.RegexOp.Conformable`?) protocol(s)
- [x] change variable names refering to `spec`(s) to `vow`(s)?
- [ ] refactor `Vow.Conformable.Map` to accept maps with *at least* the listed keys (the given map can have more, the values just remain unconformed), effectively changing this from the idea of a 'fixed' or 'static' map, to more how pattern matching in Elixir/Erlang works on maps
