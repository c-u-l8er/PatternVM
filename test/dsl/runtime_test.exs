defmodule PatternVM.DSL.RuntimeTest do
  use ExUnit.Case

  # Define a simple test module with the DSL
  defmodule SimplePatterns do
    use PatternVM.DSL

    # Define patterns
    singleton(:config)
    factory(:product_factory, [:widget])

    # Define a workflow
    workflow(
      :test_workflow,
      sequence([
        create_product(:product_factory, :widget)
      ])
    )
  end

  setup do
    # Clear test logs before each test
    PatternVM.Logger.clear_test_logs()
    :ok
  end

  test "execute_definition initializes patterns" do
    # Execute definition and count patterns
    initial_logs_count = length(PatternVM.Logger.get_test_logs())

    # Execute definition
    workflows = PatternVM.DSL.Runtime.execute_definition(SimplePatterns)

    # Check logs to verify pattern registration
    logs = PatternVM.Logger.get_test_logs()
    new_logs = length(logs) - initial_logs_count

    # Verify expected behavior
    assert new_logs > 0
    assert workflows == [:test_workflow]

    # Check for specific registration log entries
    registration_logs =
      Enum.filter(logs, fn {source, action, _} ->
        source == "PatternVM" && action == "register_pattern"
      end)

    # config and product_factory
    assert length(registration_logs) >= 2
  end

  test "execute_workflow runs the specified workflow" do
    # Create a workflow that records context changes
    defmodule ContextWorkflow do
      use PatternVM.DSL

      factory(:test_factory, [:test])

      workflow(
        :context_test,
        sequence([
          create_product(:test_factory, :test),
          notify("test", %{executed: true})
        ])
      )
    end

    # Initialize patterns
    PatternVM.DSL.Runtime.execute_definition(ContextWorkflow)

    # Execute the workflow
    context = PatternVM.DSL.Runtime.execute_workflow(ContextWorkflow, :context_test)

    # Verify context contains expected results
    assert Map.has_key?(context, :last_result)
    # From the notify step
    assert context.last_result.executed == true
  end
end
