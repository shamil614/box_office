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
             {:available, %{default_state: :available, show_seat: show_seat}}
  end

  test "spawn a process to track the current state", context do
    %{show_seat: show_seat, customer: _customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat)

    assert ShowSeatState.current_state(pid) == :available
  end

  test "holds a seat for a set interval and resets state on timeout", context do
    %{show_seat: show_seat, customer: customer} = context

    {:ok, pid} = ShowSeatState.start_link(show_seat)

    assert ShowSeatState.current_state(pid) == :available

    assert ShowSeatState.hold(pid, customer) == {:ok, :held}
    assert {:held, %{current_customer: customer}} = ShowSeatState.get_state(pid)

    Process.sleep(1_001)

    assert {:available, %{current_customer: nil}} = ShowSeatState.get_state(pid)
  end
end
