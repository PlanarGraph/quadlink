defmodule Quadlink.Game do
  use GenServer

  @board %{1 => %{}, 2 => %{}, 3 => %{}, 4 => %{}, 5 => %{}, 6 => %{}, 7 => %{}}

  defmodule State do
    defstruct [:id, :board, :turn, :game_state]
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: via_tuple(id))
  end

  def make_move(id, name, column) do
    GenServer.cast(via_tuple(id), {:make_move, name, column})
  end

  def register_player(id, name) do
    GenServer.call(via_tuple(id), {:register, name})
  end

  def reset(id) do
    GenServer.cast(via_tuple(id), :reset)
  end

  def get_game_state(id) do
    GenServer.call(via_tuple(id), :get_game_state)
  end

  @impl true
  def init(id) do
    :timer.send_interval(30_000, self(), :check_disconnect)

    {:ok, %State{board: @board, id: id, turn: "yellow", game_state: :playing}}
  end

  @impl true
  def handle_call({:register, name}, {pid, _}, state) do
    topic = "players:" <> state.id
    players = QuadlinkWeb.Presence.list(topic)

    cond do
      Enum.count(players) == 2 ->
        {:reply, {:error, :full}, state}

      name in Map.keys(players) ->
        {:reply, {:error, :name_taken}, state}

      true ->
        available_colors =
          players
          |> Enum.map(fn {_name, atts} -> hd(atts.metas).color end)
          |> (fn taken -> ["yellow", "purple"] -- taken end).()

        selected_color = hd(available_colors)

        ### register the player's pid for tracking
        QuadlinkWeb.Presence.track(
          pid,
          topic,
          name,
          %{online_at: inspect(System.system_time(:second)), color: selected_color}
        )

        {:reply, {:ok, selected_color, state.game_state}, state}
    end
  end

  @impl true
  def handle_call(:get_game_state, _, state) do
    {:reply, state.game_state, state}
  end

  @impl true
  def handle_cast({:make_move, name, column}, state) do
    ### Get the user's color, verifying they are still playing
    ### by checking the presence.
    color =
      QuadlinkWeb.Presence.list("players:" <> state.id)
      |> Map.get(name)
      |> Map.get(:metas)
      |> hd()
      |> Map.get(:color)

    condition =
      state.game_state == :playing &&
        color == state.turn &&
        Enum.count(state.board[column]) < 6

    if condition do
      ### update board
      row =
        state.board[column]
        |> Map.keys()
        |> Enum.max(fn -> 0 end)
        |> Kernel.+(1)

      board = Map.update!(state.board, column, &Map.put(&1, row, color))

      ### check win
      ###
      win = check_win(board, column, row)

      Phoenix.PubSub.broadcast(Quadlink.PubSub, "game:" <> state.id, {:update, board})

      color_prime = hd(["yellow", "purple"] -- [color])

      state_prime =
        state
        |> Map.put(:board, board)
        |> Map.put(:turn, color_prime)

      if win do
        Phoenix.PubSub.broadcast(Quadlink.PubSub, "game:" <> state.id, {:winner, name})
        {:noreply, Map.put(state_prime, :game_state, :game_over)}
      else
        {:noreply, state_prime}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:reset, state) do
    Phoenix.PubSub.broadcast(Quadlink.PubSub, "game:" <> state.id, :reset)

    state
    |> Map.put(:board, @board)
    |> Map.put(:turn, "yellow")
    |> Map.put(:game_state, :playing)
    |> (fn st -> {:noreply, st} end).()
  end

  @impl true
  def handle_info(:check_disconnect, state) do
    players = QuadlinkWeb.Presence.list("players:" <> state.id)

    if Enum.count(players) == 0 do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :normal
  end

  defp check_win(board, col, row) do
    rows =
      for i <- 0..3,
          do: [
            board[col][row - i],
            board[col][row - i + 1],
            board[col][row - i + 2],
            board[col][row - i + 3]
          ]

    cols =
      for i <- 0..3,
          do: [
            board[col - i][row],
            board[col - i + 1][row],
            board[col - i + 2][row],
            board[col - i + 3][row]
          ]

    diag_lefts =
      for i <- 0..3,
          do: [
            board[col + i][row - i],
            board[col + i - 1][row - i + 1],
            board[col + i - 2][row - i + 2],
            board[col + i - 3][row - i + 3]
          ]

    diag_rights =
      for i <- 0..3,
          do: [
            board[col - i][row - i],
            board[col - i + 1][row - i + 1],
            board[col - i + 2][row - i + 2],
            board[col - i + 3][row - i + 3]
          ]

    (rows ++ cols ++ diag_lefts ++ diag_rights)
    |> Enum.filter(&(not Enum.member?(&1, nil)))
    |> Enum.any?(fn set ->
      MapSet.new(set) |> Enum.count() == 1
    end)
  end

  defp via_tuple(id) do
    Quadlink.Registry.via_tuple({__MODULE__, id})
  end
end
