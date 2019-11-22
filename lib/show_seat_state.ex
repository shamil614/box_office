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

  def get_state(pid) do
    :sys.get_state(pid)
  end

  def current_state(pid) do
    {current_state, _data} = :sys.get_state(pid)
    current_state
  end

  def hold(pid, customer = %Customer{}) do
    GenStateMachine.call(pid, {:hold, customer})
  end

  def purchase(pid, customer = %Customer{}) do
    GenStateMachine.call(pid, {:purchase, customer})
  end

  ### Server API

  def handle_event({:call, from}, {:hold, customer}, :available, data) do
    %{state_timeout: state_timeout} = data

    data =
      data
      |> Map.put(:current_customer, customer)

    {:next_state, :hold, data, [{:reply, from, :hold}, state_timeout]}
  end

  def handle_event({:call, from}, {:purchase, customer}, :hold, data) do
    %{state_timeout: state_timeout} = data

    data =
      data
      |> Map.put(:current_customer, customer)

    {:next_state, :purchased, data, [{:reply, from, :purchased}]}
  end

  def handle_event(:timeout, _timeout, :hold, data) do
    %{default_state: default_state} = data

    data =
      data
      |> Map.put(:current_customer, nil)

    {:next_state, default_state, data}
  end
end
