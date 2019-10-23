**CHANGING RAPIDLY, USE AT YOUR OWN RISK**

# ExSpec

Alpha for `clojure.spec` implementation in Elixir

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `spec` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_spec, "~> 0.0.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/spec](https://hexdocs.pm/spec).

## TODO

- [ ] documentation
- [ ] tests
- [ ] manual tests for more complicated stuff?
- [ ] refactor `Spec.Conformable` to return 3-tuple + remove `Spec.RegexOp.Conformable`
- [ ] implement `Spec.Keys`
- [x] implement `Inspect` protocol for all `Spec.Conformable`'s
- [ ] add `unform` to the `Spec.Conformable` (and `Spec.RegexOp.Conformable`?) protocol(s)
- [ ] implement `Spec.Generatable` for all `Spec.Conformable`'s
- [ ] configure dialyzer more explicitly
- [ ] configure credo more explicitly
- [ ] add `inch_ex` documentation analysis?
- [ ] `RELEASE.md`?
- [ ] `CONTRIBUTING.md`?
- [ ] `CODE_OF_CONDUCT.md`? (via https://www.contributor-covenant.org/)
- [ ] `CHANGELOG.md`
- [x] rename?
  - [x] `Spec` -> `ExSpec`?
  - [x] `Spec.Conformable` (keep this...for now)
  - [x] `Spec.RegexOp.Conformable` -> `Spec.RegexOperator`
- [x] move from incubation repository to it's own repository
- [ ] publish to `hex.pm` & `hexdocs.pm`
- [ ] CI/CD
  - [x] GitHub Actions
    - [x] `mix compile --warnings-as-errors`
    - [x] `mix format --check-formatted`
    - [x] `mix xref unreachable --abort-if-any --include-siblings`
    - [x] `mix xref deprecated --abort-if-any --include-siblings`
    - [x] `mix credo --strict`
    - [x] `mix dialyzer --halt-exit-status`
    - [x] `mix test --trace --stale`
  - [ ] GitHub Hooks / Templates? (via https://hex.pm/packages/committee)
  - [ ] Dependabot
