defmodule QuadlinkWeb.GameLive.Spectate do
  use Phoenix.LiveView

  alias Quadlink.GameSupervisor

  @board %{1 => %{}, 2 => %{}, 3 => %{}, 4 => %{}, 5 => %{}, 6 => %{}, 7 => %{}}

  def render(assigns) do
    ~L"""
    <p class="alert alert-info"><%= live_flash(@flash, :info) %></p>
    <p class="alert alert-danger"><%= live_flash(@flash, :error) %></p>
    <section class="connect-four">
      <%= for col <- 1..7 do %>
        <div class="col">
          <%= for row <- 6..1 do %>
            <%= case @board[col][row] do %>
              <% "yellow" -> %>
                <div class="circle-yellow"></div>
              <% "purple" -> %>
                <div class="circle-purple"></div>
              <% _ -> %>
                <div class="circle-empty"></div>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    GameSupervisor.start_child(id)

    QuadlinkWeb.Endpoint.subscribe("game:" <> id)

    socket
    |> assign(:board, @board)
    |> to_tuple(:ok)
  end

  def handle_info({:update, board}, socket) do
    socket
    |> assign(:board, board)
    |> to_tuple(:noreply)
  end

  def handle_info({:winner, name}, socket) do
    socket
    |> put_flash(:info, name <> " Wins!")
    |> to_tuple(:noreply)
  end

  def handle_info(:reset, socket) do
    socket
    |> assign(:board, @board)
    |> clear_flash()
    |> to_tuple(:noreply)
  end

  defp to_tuple(socket, atom) when is_atom(atom), do: {atom, socket}
end
