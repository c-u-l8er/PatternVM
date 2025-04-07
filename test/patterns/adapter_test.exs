defmodule PatternVM.AdapterTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Adapter.initialize(%{})
    assert state == %{adapters: %{}, name: :adapter}

    # Test with custom config
    {:ok, custom_state} = PatternVM.Adapter.initialize(%{name: :test_adapter})
    assert custom_state == %{adapters: %{}, name: :test_adapter}
  end

  test "register_adapter adds an adapter function" do
    # Initialize adapter pattern
    {:ok, state} = PatternVM.Adapter.initialize(%{})
    adapter_fn = fn obj -> Map.put(obj, :adapted, true) end

    # Register an adapter
    {:ok, result, new_state} =
      PatternVM.Adapter.handle_interaction(
        :register_adapter,
        %{for_type: :test_type, adapter_fn: adapter_fn},
        state
      )

    # Verify registration
    assert result == {:registered, :test_type}
    assert Map.has_key?(new_state.adapters, :test_type)
    assert is_function(new_state.adapters[:test_type])
  end

  test "adapt uses the adapter function" do
    # Initialize adapter pattern
    {:ok, state} = PatternVM.Adapter.initialize(%{})
    adapter_fn = fn obj -> Map.put(obj, :adapted, true) end

    # Register and then use an adapter
    {:ok, _, state_with_adapter} =
      PatternVM.Adapter.handle_interaction(
        :register_adapter,
        %{for_type: :test_type, adapter_fn: adapter_fn},
        state
      )

    {:ok, result, _} =
      PatternVM.Adapter.handle_interaction(
        :adapt,
        %{object: %{original: true}, to_type: :test_type},
        state_with_adapter
      )

    # Verify adaptation
    assert result.original == true
    assert result.adapted == true
  end

  test "adapt with nonexistent adapter returns error" do
    # Initialize adapter pattern
    {:ok, state} = PatternVM.Adapter.initialize(%{})

    # Try to use a non-existent adapter
    {:error, message, _} =
      PatternVM.Adapter.handle_interaction(
        :adapt,
        %{object: %{}, to_type: :nonexistent},
        state
      )

    # Verify error
    assert message == "Adapter not found for type: nonexistent"
  end

  test "adapter pattern_name returns the expected atom" do
    assert PatternVM.Adapter.pattern_name() == :adapter
  end
end
