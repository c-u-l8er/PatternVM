defmodule PatternVM.DSL.ChainOfResponsibilityTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  # Handler functions
  defmodule TestHandlers do
    def can_handle_validation(req), do: req.type == :validation
    def handle_validation(req), do: "Validation error: #{req.message}"

    def can_handle_database(req), do: req.type == :database
    def handle_database(req), do: "Database error: #{req.message}"

    def can_handle_network(req), do: req.type == :network
    def handle_network(req), do: "Network error: #{req.code}"
  end

  test "chain of responsibility pattern definition and request handling" do
    defmodule ChainExample do
      use PatternVM.DSL
      import PatternVM.DSL.ChainOfResponsibilityTest.TestHandlers, only: []

      # Define chain of responsibility
      chain_of_responsibility(:error_chain)

      # Workflow to register handlers
      workflow(
        :register_handlers,
        sequence([
          # Register validation handler
          {:interact, :error_chain, :register_handler,
           %{
             name: :validation_handler,
             can_handle_fn:
               &PatternVM.DSL.ChainOfResponsibilityTest.TestHandlers.can_handle_validation/1,
             handle_fn: &PatternVM.DSL.ChainOfResponsibilityTest.TestHandlers.handle_validation/1,
             priority: 10
           }},

          # Register database handler
          {:interact, :error_chain, :register_handler,
           %{
             name: :database_handler,
             can_handle_fn:
               &PatternVM.DSL.ChainOfResponsibilityTest.TestHandlers.can_handle_database/1,
             handle_fn: &PatternVM.DSL.ChainOfResponsibilityTest.TestHandlers.handle_database/1,
             priority: 20
           }},

          # Register network handler
          {:interact, :error_chain, :register_handler,
           %{
             name: :network_handler,
             can_handle_fn:
               &PatternVM.DSL.ChainOfResponsibilityTest.TestHandlers.can_handle_network/1,
             handle_fn: &PatternVM.DSL.ChainOfResponsibilityTest.TestHandlers.handle_network/1,
             priority: 30
           }}
        ])
      )

      # Process validation request
      workflow(
        :process_validation,
        sequence([
          process_request(:error_chain, %{type: :validation, message: "Invalid input"})
        ])
      )

      # Process database request
      workflow(
        :process_database,
        sequence([
          process_request(:error_chain, %{type: :database, message: "Connection failed"})
        ])
      )

      # Process network request
      workflow(
        :process_network,
        sequence([
          process_request(:error_chain, %{type: :network, code: 404})
        ])
      )

      # Process unknown request
      workflow(
        :process_unknown,
        sequence([
          process_request(:error_chain, %{type: :unknown, message: "Unknown error"})
        ])
      )
    end

    # Execute definition
    ChainExample.execute()

    # Register handlers
    PatternVM.DSL.Runtime.execute_workflow(ChainExample, :register_handlers)

    # Test validation request
    result1 = PatternVM.DSL.Runtime.execute_workflow(ChainExample, :process_validation)
    assert result1.last_result == "Validation error: Invalid input"

    # Test database request
    result2 = PatternVM.DSL.Runtime.execute_workflow(ChainExample, :process_database)
    assert result2.last_result == "Database error: Connection failed"

    # Test network request
    result3 = PatternVM.DSL.Runtime.execute_workflow(ChainExample, :process_network)
    assert result3.last_result == "Network error: 404"

    # Test unknown request (should fail)
    result4 = PatternVM.DSL.Runtime.execute_workflow(ChainExample, :process_unknown)
    assert match?({:error, _}, result4.last_result)
  end

  test "handler priority in chain of responsibility" do
    defmodule PriorityChainExample do
      use PatternVM.DSL

      chain_of_responsibility(:multi_chain)

      # Workflow to register handlers that can handle the same request type
      workflow(
        :register_conflicting_handlers,
        sequence([
          # Low priority handler
          {:interact, :multi_chain, :register_handler,
           %{
             name: :low_priority,
             # Handles everything
             can_handle_fn: fn _ -> true end,
             handle_fn: fn _ -> "Low priority handler" end,
             priority: 10
           }},

          # Medium priority handler
          {:interact, :multi_chain, :register_handler,
           %{
             name: :medium_priority,
             # Handles everything
             can_handle_fn: fn _ -> true end,
             handle_fn: fn _ -> "Medium priority handler" end,
             priority: 50
           }},

          # High priority handler
          {:interact, :multi_chain, :register_handler,
           %{
             name: :high_priority,
             # Handles everything
             can_handle_fn: fn _ -> true end,
             handle_fn: fn _ -> "High priority handler" end,
             priority: 100
           }}
        ])
      )

      # Process a simple request
      workflow(
        :process_simple,
        sequence([
          process_request(:multi_chain, %{message: "Test"})
        ])
      )

      # Get the handler chain to verify priority order
      workflow(
        :get_chain,
        sequence([
          {:interact, :multi_chain, :get_handler_chain, %{}}
        ])
      )
    end

    # Execute definition
    PriorityChainExample.execute()

    # Register handlers
    PatternVM.DSL.Runtime.execute_workflow(PriorityChainExample, :register_conflicting_handlers)

    # Test request handling (highest priority should handle it)
    result1 = PatternVM.DSL.Runtime.execute_workflow(PriorityChainExample, :process_simple)
    assert result1.last_result == "High priority handler"

    # Get and verify handler chain order
    result2 = PatternVM.DSL.Runtime.execute_workflow(PriorityChainExample, :get_chain)
    assert result2.last_result == [:high_priority, :medium_priority, :low_priority]
  end
end
