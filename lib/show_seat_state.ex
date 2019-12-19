defmodule BoxOffice.ShowSeatState do
  use GenStateMachine

  alias BoxOffice.{Customer, ShowSeat}

  ### Client API
  def start_link(show_seat = %ShowSeat{}, opts \\ []) do
    %ShowSeat{current_state: current_state} = show_seat

    default_state = Keyword.get(opts, :default_state, :available)

    data = %{default_state: default_state, show_seat: show_seat}

    GenStateMachine.start_link(__MODULE__, {current_state, data})
  end

  ### Client api

  @doc """
  Get the current state and data from the process.
  """
  def get_state(pid) do
    :sys.get_state(pid)
  end

  @doc """
  Get the current state of the seat.
  """
  def current_state(pid) do
    {current_state, _data} = :sys.get_state(pid)
    current_state
  end

  @doc """
  Hold a seat temporarily for a customer.
  """
  def hold(pid, customer = %Customer{}) do
    GenStateMachine.call(pid, {:hold, customer})
  end

  ### Server API

  @doc """
  State can transition from `available` to `held`.
  """
  def handle_event({:call, from}, {:hold, customer}, :available, data) do
    %{state_timeout: state_timeout} = data

    data =
      data
      |> Map.put(:current_customer, customer)
 
     {:next_state, :held, data, [{:reply, from, {:ok, :held}}]}
  end
end
