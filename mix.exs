defmodule Vow.MixProject do
  use Mix.Project

  @app :vow
  @in_production Mix.env() == :prod
  @version "0.0.2"
  @source_url "https://github.com/naramore/vow"
  @description """
  Data specification library inspired by clojure.spec
  """

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: @in_production,
      start_permanent: @in_production,
      package: package(),
      source_url: @source_url,
      description: @description,
      docs: [
        source_ref: "v#{@version}",
        formatters: ["html", "epub"]
      ],
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.json": :test,
        "test.check": :test
      ],
      test_coverage: [
        tool: ExCoveralls
      ],
      dialyzer: [
        flags: [
          :underspecs,
          :error_handling,
          :unmatched_returns,
          :unknown,
          :race_conditions
        ],
        paths: ["_build/#{Mix.env()}/lib/#{@app}/ebin"],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE.md .formatter.exs),
      maintainers: ["Michael Naramore"],
      licenses: ["MIT"],
      links: %{
        Changelog: "#{@source_url}/blob/master/CHANGELOG.md",
        GitHub: @source_url
      }
    ]
  end

  defp elixirc_paths(env) when env in [:test, :dev],
    do: ["lib", "test/support"]

  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :stream_data]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:expat, "~> 1.0", optional: true},
      {:stream_data, "~> 0.4", optional: true},
      {:excoveralls, "~> 0.12", only: :test},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:credo_contrib, "~> 0.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      "test.check": [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "dialyzer",
        "test --cover",
        "credo"
      ]
    ]
  end
end
