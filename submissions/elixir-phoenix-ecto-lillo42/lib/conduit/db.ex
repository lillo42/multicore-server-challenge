defmodule Conduit.DB do
  @moduledoc """
  Thin query helpers over Postgrex (via Ecto's repo). The list/detail
  statements are SPEC.md's reference SQL verbatim, so the responses match
  the spec byte for byte. No data is cached anywhere: every request runs
  its SQL against Postgres while being served.
  """

  alias Conduit.Repo

  def query(sql, params \\ []), do: Ecto.Adapters.SQL.query(Repo, sql, params)
  def query!(sql, params \\ []), do: Ecto.Adapters.SQL.query!(Repo, sql, params)

  @doc "Rows of a result as maps with atom keys."
  def rows(%Postgrex.Result{columns: cols, rows: rows}) do
    keys = Enum.map(cols, &String.to_atom/1)
    Enum.map(rows, fn row -> keys |> Enum.zip(Tuple.to_list(row)) |> Map.new() end)
  end

  def all!(sql, params \\ []), do: sql |> query!(params) |> rows()

  def one!(sql, params \\ []) do
    case all!(sql, params) do
      [row | _] -> row
      [] -> nil
    end
  end

  @doc "RFC 3339 UTC with exactly 3 fractional digits (truncated), e.g. 2025-04-01T12:00:00.000Z"
  def ts(%DateTime{} = dt), do: dt |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()

  def ts(%NaiveDateTime{} = ndt),
    do: ndt |> DateTime.from_naive!("Etc/UTC") |> ts()
end
