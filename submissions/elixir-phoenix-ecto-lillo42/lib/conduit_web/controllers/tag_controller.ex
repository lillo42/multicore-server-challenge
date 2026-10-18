defmodule ConduitWeb.TagController do
  use ConduitWeb, :controller

  alias Conduit.Blog

  def index(conn, _params) do
    json(conn, %{"tags" => Blog.tags()})
  end
end
