defmodule Conduit.Accounts do
  @moduledoc "Users, authentication and profiles. Passwords: bcrypt cost 10, every time (no caching)."

  alias Conduit.DB

  @doc "Register. Returns {:ok, user} or {:error, :conflict} on duplicate username/email."
  def register(username, email, password) do
    hash = Bcrypt.hash_pwd_salt(password, log_rounds: 10)

    case DB.query(
           "INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id, username, email, bio, image",
           [username, email, hash]
         ) do
      {:ok, result} -> {:ok, result |> DB.rows() |> hd()}
      {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} -> {:error, :conflict}
    end
  end

  @doc "Login. {:ok, user} | {:error, :unauthorized}. Every login verifies the bcrypt hash."
  def login(email, password) do
    case DB.one!(
           "SELECT id, username, email, bio, image, password_hash FROM users WHERE email = $1",
           [email]
         ) do
      nil ->
        Bcrypt.no_user_verify()
        {:error, :unauthorized}

      %{password_hash: hash} = user ->
        if Bcrypt.verify_pass(password, hash) do
          {:ok, Map.delete(user, :password_hash)}
        else
          {:error, :unauthorized}
        end
    end
  end

  @doc "Fetch the token's user. nil when the user no longer exists (endpoint answers 401)."
  def get_user(id) do
    DB.one!("SELECT id, username, email, bio, image FROM users WHERE id = $1", [id])
  end

  @doc """
  Update any of email/username/password/bio/image; absent or null fields are unchanged.
  {:ok, user} | {:error, :conflict} | {:error, :unauthorized}
  """
  def update_user(id, fields) do
    password_hash =
      case Map.get(fields, "password") do
        nil -> nil
        password -> Bcrypt.hash_pwd_salt(password, log_rounds: 10)
      end

    case DB.query(
           """
           UPDATE users SET email = COALESCE($2::text, email), username = COALESCE($3::text, username),
                            password_hash = COALESCE($4::text, password_hash), bio = COALESCE($5::text, bio),
                            image = COALESCE($6::text, image)
            WHERE id = $1
           RETURNING id, username, email, bio, image
           """,
           [
             id,
             Map.get(fields, "email"),
             Map.get(fields, "username"),
             password_hash,
             Map.get(fields, "bio"),
             Map.get(fields, "image")
           ]
         ) do
      {:ok, result} ->
        case DB.rows(result) do
          [user] -> {:ok, user}
          [] -> {:error, :unauthorized}
        end

      {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
        {:error, :conflict}
    end
  end

  @doc "Profile of `username` as seen by `viewer` (0 = anonymous). nil when no such user."
  def get_profile(viewer, username) do
    DB.one!(
      """
      SELECT u.id, u.username, u.bio, u.image,
             EXISTS (SELECT 1 FROM follows fo WHERE fo.follower_id = $1 AND fo.followee_id = u.id) AS following
        FROM users u WHERE u.username = $2
      """,
      [viewer, username]
    )
  end

  @doc "Follow `username`. {:ok, profile with following: true} | {:error, :not_found}"
  def follow(viewer, username) do
    case DB.one!("SELECT id, username, bio, image FROM users WHERE username = $1", [username]) do
      nil ->
        {:error, :not_found}

      user ->
        DB.query!("INSERT INTO follows (follower_id, followee_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", [
          viewer,
          user.id
        ])

        {:ok, Map.put(user, :following, true)}
    end
  end

  @doc "Unfollow `username`. {:ok, profile with following: false} | {:error, :not_found}"
  def unfollow(viewer, username) do
    case DB.one!("SELECT id, username, bio, image FROM users WHERE username = $1", [username]) do
      nil ->
        {:error, :not_found}

      user ->
        DB.query!("DELETE FROM follows WHERE follower_id = $1 AND followee_id = $2", [viewer, user.id])
        {:ok, Map.put(user, :following, false)}
    end
  end
end
