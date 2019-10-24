**CHANGING RAPIDLY, USE AT YOUR OWN RISK**

# Vow

Vow is a data specification library inspired by [clojure.spec](https://clojure.org/guides/spec).

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
