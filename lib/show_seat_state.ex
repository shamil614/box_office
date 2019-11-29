defmodule BoxOffice.ShowSeatState do
  use GenStateMachine

  alias BoxOffice.{Customer, ShowSeat}

  ### Client API
  def start_link(show_seat = %ShowSeat{}, opts \\ []) do
    %ShowSeat{current_state: current_state} = show_seat

    default_state = Keyword.get(opts, :default_state, :available)
    state_timeout = Keyword.get(opts, :state_timeout, 5000)

    data = %{default_state: default_state, state_timeout: state_timeout, show_seat: show_seat}

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

  @doc """
  Purchase a seat for a customer.
  """
  def purchase(pid, customer = %Customer{}) do
    GenStateMachine.call(pid, {:purchase, customer})
  end

  ### Server API

  @doc """
  State can transition from `available` to `held`.
  A timeout is set to reset the state.
  """
  def handle_event({:call, from}, {:hold, customer}, :available, data) do
    %{state_timeout: state_timeout} = data

    data =
      data
      |> Map.put(:current_customer, customer)

    {:next_state, :held, data, [{:reply, from, {:ok, :held}}, {:state_timeout, state_timeout, :hold_timeout}]}
  end

  @doc """
  Can't transition from `purchased` to `held`.
  """
  def handle_event({:call, from}, {:hold, _customer}, :purchased, _data) do
    reason = {:no_transition, %{from: :held, to: :purchased}}

    {:keep_state_and_data, [{:reply, from, {:error, reason}}]}
  end

  @doc """
  State can transition from `held` to `purchased`.
  """
  def handle_event({:call, from}, {:purchase, customer}, :held, data) do
    %Customer{id: customer_id} = customer
    %{current_customer: %Customer{id: current_customer_id}} = data

    if customer_id == current_customer_id do
      data =
        data
        |> Map.put(:current_customer, customer)

      {:next_state, :purchased, data, [{:reply, from, {:ok, :purchased}}]}
    else
      reason = {:no_transition, :unavailable}
      {:keep_state_and_data, [{:reply, from, {:error, reason}}]}
    end
  end

  @doc """
  Timeout is triggered when the current state is `held`.
  State resets to the `default_state`.
  """
  def handle_event(:state_timeout, :hold_timeout, :held, data) do
    %{default_state: default_state} = data

    data =
      data
      |> Map.put(:current_customer, nil)

    {:next_state, default_state, data}
  end
end
