defmodule ConduitWeb.UserController do
  use ConduitWeb, :controller

  alias Conduit.Accounts
  alias Conduit.Auth.Token

  def register(conn, _params) do
    with {:ok, %{"username" => username, "email" => email, "password" => password}}
         when is_binary(username) and username != "" and is_binary(email) and email != "" and
                is_binary(password) and password != "" <-
           fetch_fields(conn.params, "user", ["username", "email", "password"]),
         {:ok, user} <- Accounts.register(username, email, password) do
      conn
      |> put_status(201)
      |> json(%{"user" => user_json(user, Token.sign(user.id, jwt_secret()))})
    else
      {:error, :conflict} -> error(conn, 422, "username or email is already taken")
      _ -> error(conn, 422, "username, email and password must be non-empty strings")
    end
  end

  def login(conn, _params) do
    with {:ok, %{"email" => email, "password" => password}}
         when is_binary(email) and email != "" and is_binary(password) and password != "" <-
           fetch_fields(conn.params, "user", ["email", "password"]),
         {:ok, user} <- Accounts.login(email, password) do
      json(conn, %{"user" => user_json(user, Token.sign(user.id, jwt_secret()))})
    else
      {:error, :unauthorized} -> error(conn, 401, "invalid email or password")
      _ -> error(conn, 422, "email and password must be non-empty strings")
    end
  end

  def current(conn, _params) do
    case Accounts.get_user(conn.assigns.viewer) do
      nil -> error(conn, 401, "user not found")
      user -> json(conn, %{"user" => user_json(user, conn.assigns.token)})
    end
  end

  def update(conn, _params) do
    with {:ok, fields} <- fetch_fields(conn.params, "user", ["email", "username", "password", "bio", "image"]),
         {:ok, user} <- Accounts.update_user(conn.assigns.viewer, fields) do
      json(conn, %{"user" => user_json(user, conn.assigns.token)})
    else
      {:error, :conflict} -> error(conn, 422, "username or email is already taken")
      {:error, :unauthorized} -> error(conn, 401, "user not found")
      _ -> error(conn, 422, "fields must be strings or null")
    end
  end

  defp user_json(user, token) do
    %{
      "email" => user.email,
      "token" => token,
      "username" => user.username,
      "bio" => user.bio,
      "image" => user.image
    }
  end

  defp jwt_secret, do: Application.fetch_env!(:conduit, :jwt_secret)
end
