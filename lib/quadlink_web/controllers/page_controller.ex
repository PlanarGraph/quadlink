defmodule QuadlinkWeb.PageController do
  use QuadlinkWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
