defmodule Conduit.Application do
  use Application

  @impl true
  def start(_type, _args) do
    db_opts =
      :conduit
      |> Application.fetch_env!(:db_opts)
      |> Keyword.put(:name, Conduit.DB)

    children = [
      # Postgrex connection pool (DBConnection), configured from DATABASE_URL.
      %{id: Conduit.DB, start: {Postgrex, :start_link, [db_opts]}},
      ConduitWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Conduit.Supervisor)
  end
end
