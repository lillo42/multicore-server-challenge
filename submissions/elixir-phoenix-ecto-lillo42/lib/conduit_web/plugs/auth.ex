defmodule ConduitWeb.Plugs.Auth do
  @moduledoc """
  `Authorization: Token <jwt>`.
  - mode :required - missing or invalid token halts with 401.
  - mode :optional - no header means anonymous (viewer = 0); a present but
    invalid header halts with 401.
  """

  import Plug.Conn

  alias Conduit.Auth.Token

  def init(opts), do: Keyword.fetch!(opts, :mode)

  def call(conn, mode) do
    secret = Application.fetch_env!(:conduit, :jwt_secret)

    case get_req_header(conn, "authorization") do
      [] ->
        case mode do
          :optional -> assign(conn, :viewer, 0)
          :required -> unauthorized(conn)
        end

      ["Token " <> token] ->
        case Token.verify(token, secret) do
          {:ok, user_id} -> conn |> assign(:viewer, user_id) |> assign(:token, token)
          :error -> unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{"errors" => %{"body" => ["unauthorized"]}}))
    |> halt()
  end
end
