defmodule PatternVM.UUID do
  @moduledoc """
  UUID generation for PatternVM.
  In tests, generates predictable IDs.
  """

  def uuid4 do
    "test-uuid-#{System.unique_integer([:positive])}"
  end
end
