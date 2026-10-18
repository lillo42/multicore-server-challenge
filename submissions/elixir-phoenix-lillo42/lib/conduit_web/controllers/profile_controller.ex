defmodule ConduitWeb.ProfileController do
  use ConduitWeb, :controller

  alias Conduit.Accounts

  def show(conn, %{"username" => username}) do
    case Accounts.get_profile(conn.assigns.viewer, username) do
      nil -> error(conn, 404, "profile not found")
      profile -> json(conn, %{"profile" => profile_json(profile)})
    end
  end

  def follow(conn, %{"username" => username}) do
    case Accounts.follow(conn.assigns.viewer, username) do
      {:ok, profile} -> json(conn, %{"profile" => profile_json(profile)})
      {:error, :not_found} -> error(conn, 404, "profile not found")
    end
  end

  def unfollow(conn, %{"username" => username}) do
    case Accounts.unfollow(conn.assigns.viewer, username) do
      {:ok, profile} -> json(conn, %{"profile" => profile_json(profile)})
      {:error, :not_found} -> error(conn, 404, "profile not found")
    end
  end

  defp profile_json(profile) do
    %{
      "username" => profile.username,
      "bio" => profile.bio,
      "image" => profile.image,
      "following" => profile.following
    }
  end
end
