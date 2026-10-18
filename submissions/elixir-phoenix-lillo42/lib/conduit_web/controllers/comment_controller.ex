defmodule ConduitWeb.CommentController do
  use ConduitWeb, :controller

  alias Conduit.Blog

  def index(conn, %{"slug" => slug}) do
    case Blog.list_comments(conn.assigns.viewer, slug) do
      {:ok, comments} -> json(conn, %{"comments" => comments})
      {:error, :not_found} -> error(conn, 404, "article not found")
    end
  end

  def create(conn, %{"slug" => slug}) do
    with {:ok, %{"body" => body}} when is_binary(body) and body != "" <-
           fetch_fields(conn.params, "comment", ["body"]),
         {:ok, comment} <- Blog.create_comment(conn.assigns.viewer, slug, body) do
      conn |> put_status(201) |> json(%{"comment" => comment})
    else
      {:error, :not_found} -> error(conn, 404, "article not found")
      _ -> error(conn, 422, "body must be a non-empty string")
    end
  end

  def delete(conn, %{"slug" => slug, "id" => id}) do
    with {:ok, id} <- parse_id(id),
         :ok <- Blog.delete_comment(conn.assigns.viewer, slug, id) do
      send_resp(conn, 204, "")
    else
      {:error, :not_found} -> error(conn, 404, "comment not found")
      {:error, :forbidden} -> error(conn, 403, "not the author")
      _ -> error(conn, 404, "comment not found")
    end
  end

  # A non-integer :id is a 404, not a 422.
  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp parse_id(_), do: :error
end
