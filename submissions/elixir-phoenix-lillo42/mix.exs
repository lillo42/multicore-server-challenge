defmodule Conduit.MixProject do
  use Mix.Project

  def project do
    [
      app: :conduit,
      version: "1.0.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        conduit: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  def application do
    [
      mod: {Conduit.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  # All versions pinned exactly. TODO before submitting: run `mix deps.get`
  # once and commit the generated mix.lock (pins transitive deps too).
  defp deps do
    [
      {:phoenix, "== 1.8.15"},
      {:postgrex, "== 0.22.4"},
      {:bandit, "== 1.13.1"},
      {:jason, "== 1.4.4"},
      {:bcrypt_elixir, "== 3.3.2"}
    ]
  end
end
