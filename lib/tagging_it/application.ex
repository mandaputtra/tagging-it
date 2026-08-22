defmodule TaggingIt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TaggingItWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:tagging_it, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TaggingIt.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TaggingIt.Finch},
      # Start a worker by calling: TaggingIt.Worker.start_link(arg)
      # {TaggingIt.Worker, arg},
      # Start to serve requests, typically the last entry
      TaggingItWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TaggingIt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TaggingItWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
