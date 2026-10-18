defmodule ConduitWeb.ArticleController do
  use ConduitWeb, :controller

  alias Conduit.Blog

  def index(conn, _params) do
    with {:ok, limit, offset} <- parse_paging(conn.query_params) do
      filter =
        cond do
          tag = conn.query_params["tag"] -> {:tag, tag}
          author = conn.query_params["author"] -> {:author, author}
          favorited = conn.query_params["favorited"] -> {:favorited, favorited}
          true -> :none
        end

      json(conn, Blog.list_articles(conn.assigns.viewer, limit, offset, filter))
    else
      :error -> error(conn, 422, "limit must be an integer in 1..100 and offset a non-negative integer")
    end
  end

  def feed(conn, _params) do
    case parse_paging(conn.query_params) do
      {:ok, limit, offset} -> json(conn, Blog.feed(conn.assigns.viewer, limit, offset))
      :error -> error(conn, 422, "limit must be an integer in 1..100 and offset a non-negative integer")
    end
  end

  def show(conn, %{"slug" => slug}) do
    case Blog.get_article(conn.assigns.viewer, slug) do
      nil -> error(conn, 404, "article not found")
      article -> json(conn, %{"article" => article})
    end
  end

  def create(conn, _params) do
    with {:ok, %{"title" => title, "description" => description, "body" => body}}
         when is_binary(title) and title != "" and is_binary(description) and description != "" and
                is_binary(body) and body != "" <-
           fetch_fields(conn.params, "article", ["title", "description", "body"]),
         {:ok, tag_list} <- fetch_tag_list(conn.params["article"]) do
      conn
      |> put_status(201)
      |> json(%{"article" => Blog.create_article(conn.assigns.viewer, title, description, body, tag_list)})
    else
      _ -> error(conn, 422, "title, description and body must be non-empty strings; tagList must be a list of non-empty strings")
    end
  end

  def update(conn, %{"slug" => slug}) do
    with {:ok, fields} <- fetch_fields(conn.params, "article", ["title", "description", "body"]),
         {:ok, article} <-
           Blog.update_article(
             conn.assigns.viewer,
             slug,
             Map.get(fields, "title"),
             Map.get(fields, "description"),
             Map.get(fields, "body")
           ) do
      json(conn, %{"article" => article})
    else
      {:error, :not_found} -> error(conn, 404, "article not found")
      {:error, :forbidden} -> error(conn, 403, "not the author")
      _ -> error(conn, 422, "fields must be strings or null")
    end
  end

  def delete(conn, %{"slug" => slug}) do
    case Blog.delete_article(conn.assigns.viewer, slug) do
      :ok -> send_resp(conn, 204, "")
      {:error, :not_found} -> error(conn, 404, "article not found")
      {:error, :forbidden} -> error(conn, 403, "not the author")
    end
  end

  def favorite(conn, %{"slug" => slug}) do
    case Blog.favorite(conn.assigns.viewer, slug) do
      {:ok, article} -> json(conn, %{"article" => article})
      {:error, :not_found} -> error(conn, 404, "article not found")
    end
  end

  def unfavorite(conn, %{"slug" => slug}) do
    case Blog.unfavorite(conn.assigns.viewer, slug) do
      {:ok, article} -> json(conn, %{"article" => article})
      {:error, :not_found} -> error(conn, 404, "article not found")
    end
  end

  defp fetch_tag_list(article) when is_map(article) do
    case Map.get(article, "tagList") do
      nil ->
        {:ok, []}

      tags when is_list(tags) ->
        if Enum.all?(tags, &(is_binary(&1) and &1 != "")),
          do: {:ok, tags},
          else: :error

      _ ->
        :error
    end
  end

  defp fetch_tag_list(_), do: :error
end
