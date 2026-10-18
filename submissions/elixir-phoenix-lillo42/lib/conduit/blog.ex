defmodule Conduit.Blog do
  @moduledoc """
  Articles, comments, favorites and tags. SQL is SPEC.md's reference SQL;
  $1 is the viewer id (0 when anonymous) in the shared selects.
  """

  alias Conduit.DB

  @article_list_select """
  SELECT a.id, a.slug, a.title, a.description, a.created_at, a.updated_at,
         ARRAY(SELECT t.name FROM article_tags at JOIN tags t ON t.id = at.tag_id
                WHERE at.article_id = a.id ORDER BY t.name) AS tag_list,
         (SELECT count(*) FROM favorites f WHERE f.article_id = a.id) AS favorites_count,
         EXISTS (SELECT 1 FROM favorites f WHERE f.article_id = a.id AND f.user_id = $1) AS favorited,
         u.username, u.bio, u.image,
         EXISTS (SELECT 1 FROM follows fo WHERE fo.follower_id = $1 AND fo.followee_id = a.author_id) AS following
    FROM articles a
    JOIN users u ON u.id = a.author_id
  """

  @article_full_select """
  SELECT a.id, a.slug, a.title, a.description, a.body, a.created_at, a.updated_at,
         ARRAY(SELECT t.name FROM article_tags at JOIN tags t ON t.id = at.tag_id
                WHERE at.article_id = a.id ORDER BY t.name) AS tag_list,
         (SELECT count(*) FROM favorites f WHERE f.article_id = a.id) AS favorites_count,
         EXISTS (SELECT 1 FROM favorites f WHERE f.article_id = a.id AND f.user_id = $1) AS favorited,
         u.username, u.bio, u.image,
         EXISTS (SELECT 1 FROM follows fo WHERE fo.follower_id = $1 AND fo.followee_id = a.author_id) AS following
    FROM articles a
    JOIN users u ON u.id = a.author_id
  """

  @order_page " ORDER BY a.id DESC LIMIT $2 OFFSET $3"

  # SLUGIFY(x), computed by Postgres so it is byte-identical to the reference.
  @slugify "trim(both '-' from lower(regexp_replace(%s, '[^A-Za-z0-9]+', '-', 'g')))"

  ## Articles

  @doc "List page + capped count. filter: :none | {:tag | :author | :favorited, name}."
  def list_articles(viewer, limit, offset, filter) do
    {page_sql, count_sql, page_params, count_params} =
      case filter do
        :none ->
          {
            @article_list_select <> @order_page,
            "SELECT count(*) FROM (SELECT 1 FROM articles a LIMIT 1000) s",
            [viewer, limit, offset],
            []
          }

        {:tag, tag} ->
          {
            @article_list_select <>
              " WHERE a.id IN (SELECT at.article_id FROM article_tags at WHERE at.tag_id = (SELECT t.id FROM tags t WHERE t.name = $4) ORDER BY at.article_id DESC LIMIT $2 OFFSET $3) ORDER BY a.id DESC",
            "SELECT count(*) FROM (SELECT 1 FROM article_tags at WHERE at.tag_id = (SELECT t.id FROM tags t WHERE t.name = $1) LIMIT 1000) s",
            [viewer, limit, offset, tag],
            [tag]
          }

        {:author, author} ->
          {
            @article_list_select <>
              " WHERE a.author_id = (SELECT au.id FROM users au WHERE au.username = $4)" <> @order_page,
            "SELECT count(*) FROM (SELECT 1 FROM articles a WHERE a.author_id = (SELECT u.id FROM users u WHERE u.username = $1) LIMIT 1000) s",
            [viewer, limit, offset, author],
            [author]
          }

        {:favorited, username} ->
          {
            @article_list_select <>
              " WHERE a.id IN (SELECT f.article_id FROM favorites f WHERE f.user_id = (SELECT fu.id FROM users fu WHERE fu.username = $4) ORDER BY f.article_id DESC LIMIT $2 OFFSET $3) ORDER BY a.id DESC",
            "SELECT count(*) FROM (SELECT 1 FROM favorites f WHERE f.user_id = (SELECT fu.id FROM users fu WHERE fu.username = $1) LIMIT 1000) s",
            [viewer, limit, offset, username],
            [username]
          }
      end

    articles =
      page_sql
      |> DB.all!(page_params)
      |> Enum.map(&article_json(&1, false))

    %{count: count} = DB.one!(count_sql, count_params)
    %{"articles" => articles, "articlesCount" => count}
  end

  @doc "Personal feed: newest articles by authors the viewer follows. Auth required."
  def feed(viewer, limit, offset) do
    page_sql =
      @article_list_select <>
        """
         WHERE a.id IN (SELECT x.id FROM follows fo CROSS JOIN LATERAL
            (SELECT a2.id FROM articles a2 WHERE a2.author_id = fo.followee_id ORDER BY a2.id DESC LIMIT ($2::int + $3::int)) x
          WHERE fo.follower_id = $1 ORDER BY x.id DESC LIMIT $2 OFFSET $3) ORDER BY a.id DESC
        """

    count_sql =
      "SELECT count(*) FROM (SELECT 1 FROM articles a WHERE a.author_id IN (SELECT fo.followee_id FROM follows fo WHERE fo.follower_id = $1) LIMIT 1000) s"

    articles =
      page_sql
      |> DB.all!([viewer, limit, offset])
      |> Enum.map(&article_json(&1, false))

    %{count: count} = DB.one!(count_sql, [viewer])
    %{"articles" => articles, "articlesCount" => count}
  end

  @doc "Single article by slug (with body). nil when no such slug."
  def get_article(viewer, slug) do
    case DB.one!(@article_full_select <> " WHERE a.slug = $2", [viewer, slug]) do
      nil -> nil
      row -> article_json(row, true)
    end
  end

  defp get_article_by_id(viewer, id) do
    case DB.one!(@article_full_select <> " WHERE a.id = $2", [viewer, id]) do
      nil -> nil
      row -> article_json(row, true)
    end
  end

  @doc "Create an article (single transaction), then read it back. Returns the full article JSON."
  def create_article(author_id, title, description, body, tag_list) do
    slugify = :io_lib.format(@slugify, [~c"$2"]) |> IO.iodata_to_binary()

    {:ok, id} =
      DB.transaction(fn conn ->
        %{id: id} =
          DB.one!(
            conn,
            """
            INSERT INTO articles (id, slug, author_id, title, description, body)
            SELECT n.id, #{slugify} || '-' || n.id, $1, $2, $3, $4
              FROM (SELECT nextval(pg_get_serial_sequence('articles', 'id')) AS id) n
            RETURNING id
            """,
            [author_id, title, description, body]
          )

        if tag_list != [] do
          DB.query!(
            conn,
            "INSERT INTO tags (name) SELECT DISTINCT unnest($1::text[]) ON CONFLICT (name) DO NOTHING",
            [tag_list]
          )

          DB.query!(
            conn,
            "INSERT INTO article_tags (article_id, tag_id) SELECT $1, t.id FROM tags t WHERE t.name = ANY($2::text[])",
            [id, tag_list]
          )
        end

        id
      end)

    get_article_by_id(author_id, id)
  end

  @doc """
  Update title/description/body; absent or null fields are unchanged.
  {:ok, article} | {:error, :not_found} | {:error, :forbidden}
  """
  def update_article(viewer, slug, title, description, body) do
    case DB.one!("SELECT id, author_id FROM articles WHERE slug = $1", [slug]) do
      nil ->
        {:error, :not_found}

      %{author_id: author_id} when author_id != viewer ->
        {:error, :forbidden}

      %{id: id} ->
        slugify = :io_lib.format(@slugify, [~c"$2"]) |> IO.iodata_to_binary()

        DB.query!(
          """
          UPDATE articles SET title = COALESCE($2::text, title), description = COALESCE($3::text, description),
                 body = COALESCE($4::text, body),
                 slug = CASE WHEN $2::text IS NULL THEN slug ELSE #{slugify} || '-' || id END,
                 updated_at = now()
           WHERE id = $1
          """,
          [id, title, description, body]
        )

        {:ok, get_article_by_id(viewer, id)}
    end
  end

  @doc ":ok | {:error, :not_found} | {:error, :forbidden}"
  def delete_article(viewer, slug) do
    case DB.one!("SELECT id, author_id FROM articles WHERE slug = $1", [slug]) do
      nil -> {:error, :not_found}
      %{author_id: author_id} when author_id != viewer -> {:error, :forbidden}
      %{id: id} -> DB.query!("DELETE FROM articles WHERE id = $1", [id]) && :ok
    end
  end

  ## Favorites

  def favorite(viewer, slug), do: change_favorite(viewer, slug, :favorite)
  def unfavorite(viewer, slug), do: change_favorite(viewer, slug, :unfavorite)

  defp change_favorite(viewer, slug, action) do
    case DB.one!("SELECT id FROM articles WHERE slug = $1", [slug]) do
      nil ->
        {:error, :not_found}

      %{id: id} ->
        case action do
          :favorite ->
            DB.query!(
              "INSERT INTO favorites (user_id, article_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
              [viewer, id]
            )

          :unfavorite ->
            DB.query!("DELETE FROM favorites WHERE user_id = $1 AND article_id = $2", [viewer, id])
        end

        {:ok, get_article_by_id(viewer, id)}
    end
  end

  ## Comments

  @doc "Newest 100 comments of the article. {:ok, comments} | {:error, :not_found}"
  def list_comments(viewer, slug) do
    case DB.one!("SELECT id FROM articles WHERE slug = $1", [slug]) do
      nil ->
        {:error, :not_found}

      %{id: id} ->
        comments =
          DB.all!(
            """
            SELECT c.id, c.body, c.created_at, c.updated_at, u.username, u.bio, u.image,
                   EXISTS (SELECT 1 FROM follows fo WHERE fo.follower_id = $1 AND fo.followee_id = c.author_id) AS following
              FROM comments c JOIN users u ON u.id = c.author_id
             WHERE c.article_id = $2
             ORDER BY c.created_at DESC, c.id DESC
             LIMIT 100
            """,
            [viewer, id]
          )

        {:ok, Enum.map(comments, &comment_json/1)}
    end
  end

  @doc "Add a comment. {:ok, comment} (author.following = false) | {:error, :not_found}"
  def create_comment(viewer, slug, body) do
    case DB.one!("SELECT id FROM articles WHERE slug = $1", [slug]) do
      nil ->
        {:error, :not_found}

      %{id: article_id} ->
        row =
          DB.one!(
            """
            WITH c AS (INSERT INTO comments (article_id, author_id, body) VALUES ($1, $2, $3)
                       RETURNING id, body, created_at, updated_at, author_id)
            SELECT c.id, c.body, c.created_at, c.updated_at, u.username, u.bio, u.image
              FROM c JOIN users u ON u.id = c.author_id
            """,
            [article_id, viewer, body]
          )

        {:ok, comment_json(Map.put(row, :following, false))}
    end
  end

  @doc ":ok | {:error, :not_found} | {:error, :forbidden}"
  def delete_comment(viewer, slug, id) do
    case DB.one!(
           """
           SELECT c.author_id FROM comments c JOIN articles a ON a.id = c.article_id
            WHERE c.id = $1 AND a.slug = $2
           """,
           [id, slug]
         ) do
      nil ->
        {:error, :not_found}

      %{author_id: author_id} when author_id != viewer ->
        {:error, :forbidden}

      _ ->
        DB.query!("DELETE FROM comments WHERE id = $1", [id])
        :ok
    end
  end

  ## Tags

  def tags do
    "SELECT name FROM tags ORDER BY name"
    |> DB.all!()
    |> Enum.map(& &1.name)
  end

  ## JSON shapes (plain maps, encoded by Jason)

  defp article_json(row, with_body?) do
    base = %{
      "slug" => row.slug,
      "title" => row.title,
      "description" => row.description,
      "tagList" => row.tag_list,
      "createdAt" => DB.ts(row.created_at),
      "updatedAt" => DB.ts(row.updated_at),
      "favorited" => row.favorited,
      "favoritesCount" => row.favorites_count,
      "author" => %{
        "username" => row.username,
        "bio" => row.bio,
        "image" => row.image,
        "following" => row.following
      }
    }

    if with_body?, do: Map.put(base, "body", row.body), else: base
  end

  defp comment_json(row) do
    %{
      "id" => row.id,
      "createdAt" => DB.ts(row.created_at),
      "updatedAt" => DB.ts(row.updated_at),
      "body" => row.body,
      "author" => %{
        "username" => row.username,
        "bio" => row.bio,
        "image" => row.image,
        "following" => row.following
      }
    }
  end
end
