defmodule Conduit.DB do
  @moduledoc """
  Thin helpers over Postgrex (DBConnection pool), started as a child in
  `Conduit.Application`. The list/detail statements are SPEC.md's reference
  SQL verbatim, so responses match the spec byte for byte. No data is cached
  anywhere: every request runs its SQL against Postgres while being served.
  The only "caches" are the connection pool and per-connection prepared
  statements - both explicitly allowed by the rules.

  Functions take an optional first argument for a transaction connection:
  inside `transaction/1`, queries must run on the given conn, otherwise they
  would silently check out a different pooled connection and escape the
  transaction.
  """

  def query(sql, params \\ []), do: query(__MODULE__, sql, params)
  def query(conn, sql, params), do: Postgrex.query(conn, sql, params)

  def query!(sql, params \\ []), do: query!(__MODULE__, sql, params)
  def query!(conn, sql, params), do: Postgrex.query!(conn, sql, params)

  def transaction(fun), do: Postgrex.transaction(__MODULE__, fun)

  @doc "Rows of a result as maps with atom keys."
  def rows(%Postgrex.Result{columns: cols, rows: rows}) do
    keys = Enum.map(cols, &String.to_atom/1)
    Enum.map(rows, fn row -> keys |> Enum.zip(Tuple.to_list(row)) |> Map.new() end)
  end

  def all!(sql, params \\ []), do: all!(__MODULE__, sql, params)
  def all!(conn, sql, params), do: conn |> query!(sql, params) |> rows()

  def one!(sql, params \\ []), do: one!(__MODULE__, sql, params)

  def one!(conn, sql, params) do
    case all!(conn, sql, params) do
      [row | _] -> row
      [] -> nil
    end
  end

  @doc "RFC 3339 UTC with exactly 3 fractional digits (truncated), e.g. 2025-04-01T12:00:00.000Z"
  def ts(%DateTime{} = dt), do: dt |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()

  def ts(%NaiveDateTime{} = ndt),
    do: ndt |> DateTime.from_naive!("Etc/UTC") |> ts()
end
