defmodule PatternVM.StrategyTest do
  use ExUnit.Case

  setup do
    {:ok, state} = PatternVM.Strategy.initialize(%{})
    %{state: state}
  end

  test "registers and executes a strategy", %{state: state} do
    # Define strategy function
    strategy_fn = fn args ->
      %{result: "Processed #{args.input}", processed: true}
    end

    # Register strategy
    {:ok, {:registered, :test_strategy}, new_state} =
      PatternVM.Strategy.handle_interaction(
        :register_strategy,
        %{name: :test_strategy, function: strategy_fn},
        state
      )

    # Execute strategy
    {:ok, result, ^new_state} =
      PatternVM.Strategy.handle_interaction(
        :execute_strategy,
        %{name: :test_strategy, args: %{input: "data"}},
        new_state
      )

    assert result.result == "Processed data"
    assert result.processed == true
  end

  test "returns error for non-existent strategy", %{state: state} do
    {:error, message, ^state} =
      PatternVM.Strategy.handle_interaction(
        :execute_strategy,
        %{name: :nonexistent, args: %{}},
        state
      )

    assert message =~ "Strategy not found"
  end

  test "can register multiple strategies", %{state: state} do
    # Define two strategy functions
    strategy_a = fn _ -> "Strategy A" end
    strategy_b = fn _ -> "Strategy B" end

    # Register both strategies
    {:ok, _, state_with_a} =
      PatternVM.Strategy.handle_interaction(
        :register_strategy,
        %{name: :a, function: strategy_a},
        state
      )

    {:ok, _, state_with_both} =
      PatternVM.Strategy.handle_interaction(
        :register_strategy,
        %{name: :b, function: strategy_b},
        state_with_a
      )

    # Execute both strategies
    {:ok, result_a, _} =
      PatternVM.Strategy.handle_interaction(
        :execute_strategy,
        %{name: :a, args: nil},
        state_with_both
      )

    {:ok, result_b, _} =
      PatternVM.Strategy.handle_interaction(
        :execute_strategy,
        %{name: :b, args: nil},
        state_with_both
      )

    assert result_a == "Strategy A"
    assert result_b == "Strategy B"
  end
end
