defmodule DbOps.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()
  @source_url "https://github.com/cao7113/db_ops"
  @desc "Lightweight runtime database management operations (create, seed, drop) for Elixir/Ecto Releases without Mix."

  def project do
    [
      app: :db_ops,
      version: @version,
      elixir: "~> 1.20",
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @desc,
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ssl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.14"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "DbOps",
      extras: ["README.md"]
    ]
  end
end
