defmodule QuadlinkWeb.GameLive.Play do
  use Phoenix.LiveView

  alias Quadlink.GameSupervisor
  alias Quadlink.Game
  alias QuadlinkWeb.Router.Helpers, as: Routes

  import Phoenix.HTML.Form

  def render(assigns) do
    ~L"""
    <p class="alert alert-info"><%= live_flash(@flash, :info) %></p>
    <p class="alert alert-danger"><%= live_flash(@flash, :error) %></p>
    <%= case @state do %>
      <% :waiting -> %>
        <%= f = form_for :login, "#", [phx_submit: :register] %>
          <%= text_input f, :name %>
          <%= submit "Enter" %>
        </form>
        <%= live_redirect "Spectate Game", to: Routes.live_path(@socket, QuadlinkWeb.GameLive.Spectate, @server) %>

      <% :playing -> %>
        <div class="ctext"> Choose a column: </div>
        <section class="controller">
          <%= for col <- 1..7 do %>
            <div class="cinput" >
              <button class="cbutton-<%= @color %>" phx-click="<%= col %>">
                <%= col %>
              </button>
            </div>
          <% end %>
        </section>

      <% :game_over -> %>
        <button phx-click="restart">New Game</button>
    <% end %>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    socket
    |> assign(:server, id)
    |> assign(:state, :waiting)
    |> to_tuple(:ok)
  end

  def handle_event(
        "register",
        %{"login" => %{"name" => name}},
        %{assigns: %{server: server}} = socket
      ) do
    GameSupervisor.start_child(server)

    case Game.register_player(server, name) do
      {:error, :full} ->
        socket
        |> put_flash(:error, "The game is full")
        |> to_tuple(:noreply)

      {:error, :name_taken} ->
        socket
        |> put_flash(:error, "That name has been taken")
        |> to_tuple(:noreply)

      {:ok, color, game_state} ->
        QuadlinkWeb.Endpoint.subscribe("game:" <> server)

        socket
        |> clear_flash()
        |> assign(:color, color)
        |> assign(:name, name)
        |> assign(:state, game_state)
        |> to_tuple(:noreply)
    end
  end

  def handle_event("restart", _params, socket) do
    Game.reset(socket.assigns[:server])

    restart(socket)
  end

  def handle_event(pos, _params, socket) do
    Game.make_move(socket.assigns[:server], socket.assigns[:name], String.to_integer(pos))

    {:noreply, socket}
  end

  def handle_info({:winner, name}, socket) do
    message =
      if name == socket.assigns[:name] do
        "You Win!"
      else
        name <> " Wins!"
      end

    socket
    |> assign(:state, :game_over)
    |> put_flash(:info, message)
    |> to_tuple(:noreply)
  end

  def handle_info(:reset, socket) do
    restart(socket)
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp to_tuple(socket, atom) when is_atom(atom), do: {atom, socket}

  defp restart(socket) do
    socket
    |> assign(:state, :playing)
    |> clear_flash()
    |> to_tuple(:noreply)
  end
end
