defmodule ACPex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/lostbean/acpex"

  def project do
    [
      app: :acpex,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      name: "ACPex",
      source_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      preferred_cli_env: [precommit: :test]
    ]
  end

  def application do
    [
      mod: {ACPex.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ecto, "~> 3.11"},
      {:stream_data, "~> 1.1", only: :test},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    An Elixir implementation of the Agent Client Protocol (ACP) for editor-agent communication.
    This library implements the JSON-RPC based protocol from agentclientprotocol.com.
    """
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Protocol Spec" => "https://agentclientprotocol.com"
      },
      files: ~w(lib livebooks .formatter.exs mix.exs README.md LICENSE usage-rules.md)
    ]
  end

  defp docs do
    [
      main: "getting_started",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/acpex",
      logo: nil,
      extras: [
        "README.md",
        "docs/getting_started.md",
        "docs/building_agents.md",
        "docs/building_clients.md",
        "docs/protocol_overview.md",
        "docs/supervision_tree.md"
      ],
      groups_for_extras: [
        Guides: [
          "docs/getting_started.md",
          "docs/building_agents.md",
          "docs/building_clients.md",
          "docs/protocol_overview.md",
          "docs/supervision_tree.md"
        ]
      ],
      groups_for_modules: [
        "Core API": [ACPex],
        Behaviours: [ACPex.Agent, ACPex.Client],
        Protocol: [
          ACPex.Protocol.Connection,
          ACPex.Protocol.ConnectionSupervisor,
          ACPex.Protocol.Session,
          ACPex.Protocol.SessionSupervisor
        ],
        Schema: [ACPex.Schema.Codec],
        Transport: [ACPex.Transport.Ndjson],
        Application: [ACPex.Application]
      ]
    ]
  end

  def elixirc_paths(:test), do: ["lib", "test/support"]
  def elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      precommit: ["format", "test", "credo"]
    ]
  end
end
