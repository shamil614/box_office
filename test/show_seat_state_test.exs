defmodule BoxOffice.ShowSeatStateTest do
  use ExUnit.Case
  alias BoxOffice.{Customer, ShowSeat, ShowSeatState}

  setup do
    show_seat = %ShowSeat{id: 1, theater_id: 1, seat_id: 1, current_state: :available}
    customer = %Customer{id: 2, first_name: "Joe", last_name: "Blow"}

    {:ok, %{show_seat: show_seat, customer: customer}}
  end

  test "process holds the full state", context do
    %{show_seat: show_seat, customer: _customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat)

    full_state = ShowSeatState.get_state(pid)

    assert full_state ==
             {:available, %{default_state: :available, state_timeout: 5_000, show_seat: show_seat}}
  end

  test "spawn a process to track the current state", context do
    %{show_seat: show_seat, customer: _customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat)

    assert ShowSeatState.current_state(pid) == :available
  end

  test "holds a seat for a set interval and resets state on timeout", context do
    %{show_seat: show_seat, customer: customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat, state_timeout: 1_000)

    assert ShowSeatState.current_state(pid) == :available

    assert ShowSeatState.hold(pid, customer) == {:ok, :held}
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    Process.sleep(1_001)

    assert {:available, %{current_customer: nil}} = ShowSeatState.get_state(pid)
  end

  test "seat can transition from hold to purchased, seat can't be held after purchase", context do
    %{show_seat: show_seat, customer: customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat, state_timeout: 200)

    assert ShowSeatState.current_state(pid) == :available

    assert ShowSeatState.hold(pid, customer) == {:ok, :held}
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # state stays held before timeout is triggered
    Process.sleep(100)
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # state can transition from held to purchased
    assert ShowSeatState.purchase(pid, customer) == {:ok, :purchased}
    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # seat stays purchased after the timeout
    Process.sleep(300)
    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # seat can't go back to hold
    assert ShowSeatState.hold(pid, customer) == {:error, {:no_transition, %{from: :held, to: :purchased}}}

    # seat stays purchased
    Process.sleep(200)
    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)
  end

  test "seat can transition from hold to available but still purchased", context do
    %{show_seat: show_seat, customer: customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat, state_timeout: 200)

    assert ShowSeatState.current_state(pid) == :available

    assert ShowSeatState.hold(pid, customer) == {:ok, :held}
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # state transitions to available after timeout is triggered
    Process.sleep(201)
    assert {:available, %{current_customer: nil}} = ShowSeatState.get_state(pid)

    # state can transition from available to held
    assert ShowSeatState.hold(pid, customer) == {:ok, :held}
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # state can transition from held to purchased
    Process.sleep(100)
    assert ShowSeatState.purchase(pid, customer) == {:ok, :purchased}
    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # seat stays purchased after the timeout
    Process.sleep(300)
    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # seat can't go back to hold
    assert ShowSeatState.hold(pid, customer) == {:error, {:no_transition, %{from: :held, to: :purchased}}}

    # seat stays purchased
    Process.sleep(200)
    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)
  end

  test "a customer can't purchase another customer's held seat", context do
    %{show_seat: show_seat, customer: customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat, state_timeout: 200)

    assert ShowSeatState.current_state(pid) == :available

    assert ShowSeatState.hold(pid, customer) == {:ok, :held}
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    ticket_scalper = %Customer{id: 3, first_name: "Ticket", last_name: "Scalper"}

    # scalper can't purchase another customer's held ticket
    assert ShowSeatState.purchase(pid, ticket_scalper) == {:error, {:no_transition, :unavailable}}
    # ticket remains held by original customer
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    # state transitions back to available after timeout
    Process.sleep(1_001)
    assert {:available, %{current_customer: nil}} = ShowSeatState.get_state(pid)
  end
end
