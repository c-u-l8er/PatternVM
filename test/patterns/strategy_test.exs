defmodule PatternVM.StrategyTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Strategy.initialize(%{})
    assert state == %{strategies: %{}}
  end

  test "register_strategy adds a strategy" do
    # Initialize strategy pattern
    {:ok, state} = PatternVM.Strategy.initialize(%{})
    strategy_fn = fn args -> args * 2 end

    # Register a strategy
    {:ok, result, new_state} =
      PatternVM.Strategy.handle_interaction(
        :register_strategy,
        %{name: :double, function: strategy_fn},
        state
      )

    # Verify registration
    assert result == {:registered, :double}
    assert Map.has_key?(new_state.strategies, :double)
    assert is_function(new_state.strategies[:double])
  end

  test "execute_strategy runs the strategy function" do
    # Initialize strategy pattern
    {:ok, state} = PatternVM.Strategy.initialize(%{})
    strategy_fn = fn args -> args * 2 end

    # Register and then execute a strategy
    {:ok, _, state_with_strategy} =
      PatternVM.Strategy.handle_interaction(
        :register_strategy,
        %{name: :double, function: strategy_fn},
        state
      )

    {:ok, result, _} =
      PatternVM.Strategy.handle_interaction(
        :execute_strategy,
        %{name: :double, args: 5},
        state_with_strategy
      )

    # Verify execution
    assert result == 10
  end

  test "execute_strategy with nonexistent strategy returns error" do
    # Initialize strategy pattern
    {:ok, state} = PatternVM.Strategy.initialize(%{})

    # Try to execute a non-existent strategy
    {:error, message, _} =
      PatternVM.Strategy.handle_interaction(
        :execute_strategy,
        %{name: :nonexistent, args: 5},
        state
      )

    # Verify error
    assert message == "Strategy not found: nonexistent"
  end

  test "strategy pattern_name returns the expected atom" do
    assert PatternVM.Strategy.pattern_name() == :strategy
  end
end
