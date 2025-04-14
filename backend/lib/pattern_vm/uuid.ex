defmodule PatternVM.UUID do
  @moduledoc """
  UUID generation for PatternVM.
  In production, delegates to the real UUID library.
  In tests, generates predictable IDs.
  """

  def uuid4 do
    if Application.get_env(:pattern_vm, :testing, false) do
      "test-uuid-#{System.unique_integer([:positive])}"
    else
      UUID.uuid4()
    end
  end
end
