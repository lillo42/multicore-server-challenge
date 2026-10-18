defmodule ConduitWeb.Router do
  use ConduitWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth_required do
    plug ConduitWeb.Plugs.Auth, mode: :required
  end

  pipeline :auth_optional do
    plug ConduitWeb.Plugs.Auth, mode: :optional
  end

  # Auth-required routes first so /api/articles/feed wins over /api/articles/:slug.
  scope "/api", ConduitWeb do
    pipe_through [:api, :auth_required]

    get "/articles/feed", ArticleController, :feed

    get "/user", UserController, :current
    put "/user", UserController, :update

    post "/profiles/:username/follow", ProfileController, :follow
    delete "/profiles/:username/follow", ProfileController, :unfollow

    post "/articles", ArticleController, :create
    put "/articles/:slug", ArticleController, :update
    delete "/articles/:slug", ArticleController, :delete

    post "/articles/:slug/favorite", ArticleController, :favorite
    delete "/articles/:slug/favorite", ArticleController, :unfavorite

    post "/articles/:slug/comments", CommentController, :create
    delete "/articles/:slug/comments/:id", CommentController, :delete
  end

  scope "/api", ConduitWeb do
    pipe_through [:api, :auth_optional]

    post "/users", UserController, :register
    post "/users/login", UserController, :login

    get "/profiles/:username", ProfileController, :show

    get "/articles", ArticleController, :index
    get "/articles/:slug", ArticleController, :show
    get "/articles/:slug/comments", CommentController, :index

    get "/tags", TagController, :index
  end
end
