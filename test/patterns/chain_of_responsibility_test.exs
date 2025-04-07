defmodule PatternVM.ChainOfResponsibilityTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.ChainOfResponsibility.initialize(%{})
    assert state == %{handlers: [], name: :chain_of_responsibility}

    # Test with custom config
    {:ok, custom_state} = PatternVM.ChainOfResponsibility.initialize(%{name: :test_chain})
    assert custom_state == %{handlers: [], name: :test_chain}
  end

  test "register_handler adds a handler to the chain" do
    # Initialize chain
    {:ok, state} = PatternVM.ChainOfResponsibility.initialize(%{})

    # Create handler functions
    can_handle_fn = fn request -> request.type == :test end
    handle_fn = fn request -> "Handled #{request.message}" end

    # Register a handler
    {:ok, result, new_state} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        %{name: :test_handler, can_handle_fn: can_handle_fn, handle_fn: handle_fn, priority: 10},
        state
      )

    # Verify registration
    assert result.name == :test_handler
    assert result.priority == 10
    assert length(new_state.handlers) == 1
    [handler] = new_state.handlers
    assert handler.name == :test_handler
    assert is_function(handler.can_handle)
    assert is_function(handler.handle)
  end

  test "process_request finds and uses appropriate handler" do
    # Initialize chain with handlers
    {:ok, state} = PatternVM.ChainOfResponsibility.initialize(%{})

    validation_can_handle = fn request -> request.type == :validation end
    validation_handle = fn request -> "Validation: #{request.message}" end

    db_can_handle = fn request -> request.type == :database end
    db_handle = fn request -> "Database: #{request.message}" end

    # Add handlers in reverse priority order to test sorting
    {:ok, _, state_with_one} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        %{
          name: :db_handler,
          can_handle_fn: db_can_handle,
          handle_fn: db_handle,
          priority: 5
        },
        state
      )

    {:ok, _, state_with_both} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        %{
          name: :validation_handler,
          can_handle_fn: validation_can_handle,
          handle_fn: validation_handle,
          priority: 10
        },
        state_with_one
      )

    # Process validation request
    validation_request = %{type: :validation, message: "Invalid input"}

    {:ok, validation_result, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :process_request,
        %{request: validation_request},
        state_with_both
      )

    # Process database request
    db_request = %{type: :database, message: "Connection failed"}

    {:ok, db_result, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :process_request,
        %{request: db_request},
        state_with_both
      )

    # Verify correct handlers were used
    assert validation_result == "Validation: Invalid input"
    assert db_result == "Database: Connection failed"
  end

  test "process_request with no matching handler returns error" do
    # Initialize chain with handler
    {:ok, state} = PatternVM.ChainOfResponsibility.initialize(%{})

    validation_can_handle = fn request -> request.type == :validation end
    validation_handle = fn request -> "Validation: #{request.message}" end

    {:ok, _, state_with_handler} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        %{
          name: :validation_handler,
          can_handle_fn: validation_can_handle,
          handle_fn: validation_handle,
          priority: 10
        },
        state
      )

    # Process unhandled request type
    unknown_request = %{type: :unknown, message: "Unknown error"}

    {:error, message, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :process_request,
        %{request: unknown_request},
        state_with_handler
      )

    # Verify error
    assert message == "No handler found for request"
  end

  test "get_handler_chain returns the chain of handlers" do
    # Initialize chain with handlers
    {:ok, state} = PatternVM.ChainOfResponsibility.initialize(%{})

    # Add some handlers
    {:ok, _, state_with_one} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        %{
          name: :handler1,
          can_handle_fn: fn _ -> true end,
          handle_fn: fn _ -> :ok end,
          priority: 10
        },
        state
      )

    {:ok, _, state_with_both} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :register_handler,
        %{
          name: :handler2,
          can_handle_fn: fn _ -> true end,
          handle_fn: fn _ -> :ok end,
          priority: 20
        },
        state_with_one
      )

    # Get handler chain
    {:ok, handler_names, _} =
      PatternVM.ChainOfResponsibility.handle_interaction(
        :get_handler_chain,
        %{},
        state_with_both
      )

    # Verify chain (should be sorted by priority)
    assert handler_names == [:handler2, :handler1]
  end

  test "chain_of_responsibility pattern_name returns the expected atom" do
    assert PatternVM.ChainOfResponsibility.pattern_name() == :chain_of_responsibility
  end
end
