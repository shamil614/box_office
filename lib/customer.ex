defmodule BoxOffice.Customer do
  use GenStateMachine

  @enforce_keys [:id, :first_name, :last_name]

  defstruct id: nil,
            first_name: "",
            last_name: ""
end
