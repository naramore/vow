**CHANGING RAPIDLY, USE AT YOUR OWN RISK**

# Vow

[![Actions Status](https://github.com/naramore/vow/workflows/ElixirCI/badge.svg)](https://github.com/naramore/vow/actions)
[![Coverage Status](https://coveralls.io/repos/github/naramore/vow/badge.svg?branch=master)](https://coveralls.io/github/naramore/vow?branch=master)
[![Latest Version](https://img.shields.io/hexpm/v/vow.svg?maxAge=3600)](https://hex.pm/packages/vow)

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
- [ ] implement `Spec.Keys`
- [ ] add `unform` to the `Spec.Conformable` (and `Spec.RegexOp.Conformable`?) protocol(s)
- [ ] implement `Spec.Generatable` for all `Spec.Conformable`'s
- [ ] add caching for github actions (e.g. dialyzer, deps.get), once available
