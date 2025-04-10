defmodule PatternVM.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the PubSub system
      PatternVM.PubSub,
      # Start the Repo
      PatternVM.Repo,
      # Other children
      PatternVMWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:pattern_vm, :dns_cluster_query) || :ignore},
      # Start to serve requests
      PatternVMWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PatternVM.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PatternVMWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
