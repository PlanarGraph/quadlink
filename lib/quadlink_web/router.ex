defmodule QuadlinkWeb.Router do
  use QuadlinkWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_root_layout, {QuadlinkWeb.LayoutView, :root}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", QuadlinkWeb do
    pipe_through :browser

    live "/watch/:id", GameLive.Spectate
    live "/play/:id", GameLive.Play
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuadlinkWeb do
  #   pipe_through :api
  # end
end
