defmodule QuadlinkWeb.GameLive.Play do
  use Phoenix.LiveView

  alias Quadlink.GameSupervisor
  alias Quadlink.Game

  import Phoenix.HTML.Form

  def render(assigns) do
    ~L"""
    <%= if not(@joined) do %>
      <%= f = form_for :login, "#", [phx_submit: :register] %>
        <%= text_input f, :name %>
        <%= submit "Enter" %>
      </form>
    <% else %>
      <table>
        <tr>
          <%= for col <- 1..7 do %>
            <td><button phx-click="<%= col %>"><%= col %></button></td>
          <% end %>
        </tr>
      </table>
    <% end %>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    GameSupervisor.start_child(id)

    socket
    |> assign(:server, id)
    |> assign(:joined, false)
    |> to_tuple(:ok)
  end

  def handle_event("register", _, socket) do
    {:ok, color} = Game.register_player(socket.assigns[:server])

    socket
    |> assign(:color, color)
    |> assign(:joined, true)
    |> to_tuple(:noreply)
  end

  def handle_event(pos, _params, socket) do
    Game.make_move(socket.assigns[:server], socket.assigns[:color], String.to_integer(pos))

    {:noreply, socket}
  end

  defp to_tuple(socket, atom) when is_atom(atom), do: {atom, socket}
end
