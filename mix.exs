defmodule ICalendar.Mixfile do
  use Mix.Project

  @source_url "https://github.com/lpil/icalendar"
  @version "2.0.0"

  def project do
    [
      app: :icalendar,
      name: "ICalendar",
      version: @version,
      elixir: "~> 1.18",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [applications: [:timex, :rrule_ext]]
  end

  defp deps do
    [
      {:timex, "~> 3.4"},
      {:rrule_ext, "~> 0.15.5"},
      {:mix_test_watch, ">= 0.0.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      description: "An ICalendar file generator",
      maintainers: ["Louis Pilfold"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/icalendar/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
