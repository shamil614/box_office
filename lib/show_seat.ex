defmodule BoxOffice.ShowSeat do
  use GenStateMachine

  @enforce_keys [:id, :theater_id, :seat_id, :current_state]

  defstruct id: nil,
            theater_id: nil,
            seat_id: nil,
            current_state: :available
end
