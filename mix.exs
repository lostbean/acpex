defmodule ACPex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/acpex"

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
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
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
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "guides/which_acp.md", "guides/getting_started.md"],
      groups_for_modules: [
        Core: [ACPex, ACPex.Connection],
        Behaviours: [ACPex.Client, ACPex.Agent],
        Schema: [ACPex.Schema],
        Transport: [ACPex.Transport.Stdio]
      ]
    ]
  end
end
