defmodule PatternVM.AdapterTest do
  use ExUnit.Case

  setup do
    adapters = %{
      string_to_integer: &String.to_integer/1,
      map_to_list: fn map -> Enum.map(map, fn {k, v} -> {k, v} end) end
    }

    {:ok, state} = PatternVM.Adapter.initialize(%{adapters: adapters})
    %{state: state}
  end

  test "adapts objects using registered adapters", %{state: state} do
    # Test existing adapter
    {:ok, result, ^state} =
      PatternVM.Adapter.handle_interaction(
        :adapt,
        %{
          object: "42",
          to_type: :string_to_integer
        },
        state
      )

    assert result == 42
  end

  test "registers and uses new adapter", %{state: state} do
    adapter_fn = fn list -> Enum.join(list, ",") end

    # Register new adapter
    {:ok, {:registered, :list_to_string}, new_state} =
      PatternVM.Adapter.handle_interaction(
        :register_adapter,
        %{
          for_type: :list_to_string,
          adapter_fn: adapter_fn
        },
        state
      )

    # Use the new adapter
    {:ok, result, ^new_state} =
      PatternVM.Adapter.handle_interaction(
        :adapt,
        %{
          object: ["a", "b", "c"],
          to_type: :list_to_string
        },
        new_state
      )

    assert result == "a,b,c"
  end

  test "returns error for unknown adapter type", %{state: state} do
    {:error, message, ^state} =
      PatternVM.Adapter.handle_interaction(
        :adapt,
        %{
          object: "test",
          to_type: :unknown_adapter
        },
        state
      )

    assert message =~ "Adapter not found"
  end
end
