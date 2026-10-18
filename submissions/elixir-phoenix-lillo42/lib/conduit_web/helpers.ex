defmodule ConduitWeb.Helpers do
  @moduledoc "Shared controller helpers: error shape, paging params, body field extraction."

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @doc "The RealWorld error body: {\"errors\": {\"body\": [msg]}}."
  def error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{"errors" => %{"body" => [message]}})
  end

  @doc """
  limit (default 20, 1..100) and offset (default 0, >= 0) from the query string.
  {:ok, limit, offset} | :error (caller answers 422).
  """
  def parse_paging(query_params) do
    with {:ok, limit} <- parse_int(Map.get(query_params, "limit"), 20),
         {:ok, offset} <- parse_int(Map.get(query_params, "offset"), 0),
         true <- limit >= 1 and limit <= 100,
         true <- offset >= 0 do
      {:ok, limit, offset}
    else
      _ -> :error
    end
  end

  defp parse_int(nil, default), do: {:ok, default}

  defp parse_int(value, _default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp parse_int(_, _), do: :error

  @doc """
  Extracts `allowed` fields from the wrapped request body ({"user": {...}} etc.).
  Values must be strings or null (null = unchanged on update).
  {:ok, fields} | :error
  """
  def fetch_fields(params, wrapper, allowed) do
    case params do
      %{^wrapper => fields} when is_map(fields) ->
        fields = Map.take(fields, allowed)

        if Enum.all?(fields, fn {_k, v} -> is_nil(v) or is_binary(v) end) do
          {:ok, fields}
        else
          :error
        end

      _ ->
        :error
    end
  end
end
