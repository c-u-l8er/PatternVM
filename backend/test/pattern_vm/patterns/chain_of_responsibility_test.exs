defmodule PatternVM.ChainOfResponsibilityTest do
  use ExUnit.Case

  setup do
    {:ok, state} = PatternVM.ChainOfResponsibility.initialize(%{})
    %{state: state}
  end

  test "registers handlers and processes requests", %{state: state} do
    # Create handlers for different request types
    validation_handler = %{
      name: :validation_handler,
      can_handle: fn req -> req.type == :validation end,
      handle: fn req -> "Validation error: #{req.message}" end,
      priority: 10
    }

    db_handler = %{
      name: :db_handler,
      can_handle: fn req -> req.type == :database end,
      handle: fn req -> "Database error: #{req.message}" end,
      priority: 5
    }

    # Register handlers
    {:ok, _, state_with_validation} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        validation_handler,
        state
      )

    {:ok, _, state_with_both} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        db_handler,
        state_with_validation
      )

    # Process validation request
    {:ok, validation_result, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :process_request,
        %{request: %{type: :validation, message: "Invalid input"}},
        state_with_both
      )

    assert validation_result == "Validation error: Invalid input"

    # Process database request
    {:ok, db_result, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :process_request,
        %{request: %{type: :database, message: "Connection failed"}},
        state_with_both
      )

    assert db_result == "Database error: Connection failed"
  end

  test "respects handler priority", %{state: state} do
    # Create two handlers for the same request type with different priorities
    high_priority = %{
      name: :high_priority,
      can_handle: fn req -> req.type == :test end,
      handle: fn _ -> "High priority handler" end,
      priority: 100
    }

    low_priority = %{
      name: :low_priority,
      can_handle: fn req -> req.type == :test end,
      handle: fn _ -> "Low priority handler" end,
      priority: 10
    }

    # Register low priority first, then high priority
    {:ok, _, state1} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        low_priority,
        state
      )

    {:ok, _, state2} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        high_priority,
        state1
      )

    # Process request - high priority should handle it
    {:ok, result, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :process_request,
        %{request: %{type: :test}},
        state2
      )

    assert result == "High priority handler"
  end

  test "returns error when no handler can process request", %{state: state} do
    # Register a handler for validation requests
    handler = %{
      name: :validation_handler,
      can_handle: fn req -> req.type == :validation end,
      handle: fn _ -> "Handled" end,
      priority: 0
    }

    {:ok, _, state_with_handler} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        handler,
        state
      )

    # Try to process a different type of request
    {:error, message, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :process_request,
        %{request: %{type: :unknown}},
        state_with_handler
      )

    assert message =~ "No handler found"
  end

  test "gets the handler chain in priority order", %{state: state} do
    # Register handlers with different priorities
    handlers = [
      %{name: :medium, can_handle: fn _ -> true end, handle: fn _ -> nil end, priority: 50},
      %{name: :highest, can_handle: fn _ -> true end, handle: fn _ -> nil end, priority: 100},
      %{name: :lowest, can_handle: fn _ -> true end, handle: fn _ -> nil end, priority: 10}
    ]

    state_with_handlers =
      Enum.reduce(handlers, state, fn handler, acc_state ->
        {:ok, _, new_state} =
          PatternVM.ChainOfResponsibility.handle_interaction(
            :register_handler,
            handler,
            acc_state
          )

        new_state
      end)

    # Get handler chain
    {:ok, chain, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :get_handler_chain,
        %{},
        state_with_handlers
      )

    # Chain should be in priority order (highest first)
    assert chain == [:highest, :medium, :lowest]
  end
end
