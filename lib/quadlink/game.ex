defmodule Quadlink.Game do
  use GenServer

  @board %{1 => %{}, 2 => %{}, 3 => %{}, 4 => %{}, 5 => %{}, 6 => %{}, 7 => %{}}

  defmodule State do
    defstruct [:id, :board, :yellow, :purple]
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: via_tuple(id))
  end

  def make_move(id, color, column) do
    GenServer.cast(via_tuple(id), {:make_move, color, column})
  end

  def register_player(id) do
    GenServer.call(via_tuple(id), :register)
  end

  @impl true
  def init(id) do
    :timer.send_interval(30_000, self(), :check_disconnect)

    {:ok, %State{board: @board, id: id}}
  end

  @impl true
  def handle_call(:register, {pid, _}, state) do
    case {state.yellow, state.purple} do
      {nil, _} ->
        {:reply, {:ok, "yellow"}, Map.put(state, :yellow, pid)}

      {_, nil} ->
        {:reply, {:ok, "purple"}, Map.put(state, :purple, pid)}

      _ ->
        {:reply, {:error, :full}, state}
    end
  end

  @impl true
  def handle_cast({:make_move, color, column}, state) do
    if Enum.count(state.board[column]) < 6 do
      ### update board
      row =
        state.board[column]
        |> Map.keys()
        |> Enum.max(fn -> 0 end)
        |> Kernel.+(1)

      board = Map.update!(state.board, column, &Map.put(&1, row, color))

      ###

      ### check win
      ###
      win = check_win(board, column, row)

      Phoenix.PubSub.broadcast(Quadlink.PubSub, "game:" <> state.id, {:update, board})

      if win do
        Phoenix.PubSub.broadcast(Quadlink.PubSub, "game:" <> state.id, {:winner, color})
      end

      {:noreply, Map.put(state, :board, board)}
    else
      {:noreply, state}
    end
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

  @impl true
  def handle_info(:check_disconnect, state) do
    yellow = (state.yellow && Process.alive?(state.yellow)) || false
    purple = (state.purple && Process.alive?(state.purple)) || false

    if not (yellow or purple) do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :normal
  end

  defp via_tuple(id) do
    Quadlink.Registry.via_tuple({__MODULE__, id})
  end
end
