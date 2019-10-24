**CHANGING RAPIDLY, USE AT YOUR OWN RISK**

# Vow

Alpha for `clojure.spec` implementation in Elixir

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `spec` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vow, "~> 0.0.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/spec](https://hexdocs.pm/spec).

## TODO

- [ ] documentation
- [ ] tests
- [ ] implement `Spec.Keys`
- [ ] add `unform` to the `Spec.Conformable` (and `Spec.RegexOp.Conformable`?) protocol(s)
- [ ] implement `Spec.Generatable` for all `Spec.Conformable`'s
- [ ] publish to hex.pm github action, triggered on tag
- [ ] add caching for github actions (e.g. dialyzer, deps.get), once available
