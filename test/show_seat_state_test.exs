defmodule BoxOffice.ShowSeatStateTest do
  use ExUnit.Case
  alias BoxOffice.{Customer, ShowSeat, ShowSeatState}

  setup do
    show_seat = %ShowSeat{id: 1, theater_id: 1, seat_id: 1, current_state: :available}
    customer = %Customer{id: 2, first_name: "Joe", last_name: "Blow"}

    {:ok, %{show_seat: show_seat, customer: customer}}
  end

  test "process holds the full state", %{show_seat: show_seat} do
    {:ok, pid} = ShowSeatState.start_link(show_seat)

    full_state = ShowSeatState.get_state(pid)

    assert full_state ==
             {:available, %{default_state: :available, state_timeout: 5_000, show_seat: show_seat}}
  end

  test "spawn a process to hold the current state", %{show_seat: show_seat} do
    {:ok, pid} = ShowSeatState.start_link(show_seat)

    assert ShowSeatState.current_state(pid) == :available
  end

  test "holds a seat for a set interval and resets state on timeout", %{
    show_seat: show_seat,
    customer: customer
  } do
    {:ok, pid} = ShowSeatState.start_link(show_seat, state_timeout: 1_000)

    assert ShowSeatState.current_state(pid) == :available

    assert ShowSeatState.hold(pid, customer) == :hold
    assert {:hold, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    Process.sleep(1_001)

    assert {:available, %{current_customer: nil}} = ShowSeatState.get_state(pid)
  end

  test "seat can transition from hold to purchased, seat can't be held after purchase", %{
    show_seat: show_seat,
    customer: customer
  } do
    {:ok, pid} = ShowSeatState.start_link(show_seat, state_timeout: 1_000)

    assert ShowSeatState.current_state(pid) == :available

    assert ShowSeatState.hold(pid, customer) == :hold
    assert {:hold, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    assert ShowSeatState.purchase(pid, customer) == :purchased
    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    Process.sleep(1_001)

    assert {:purchased, %{current_customer: customer}} = ShowSeatState.get_state(pid)
  end
end
