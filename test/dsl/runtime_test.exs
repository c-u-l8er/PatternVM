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
    # Set up for runtime tests
    # Mock PatternVM to prevent actual execution
    if !Process.whereis(PatternVM) do
      defmodule PatternVM do
        def start_link(_), do: {:ok, self()}
        def register_pattern(_, _), do: {:ok, :mock_pattern}
        def interact(_, _, _), do: %{mocked: true}
        def notify_observers(_, data), do: data
      end
    end

    # Mock logger
    if !Process.whereis(PatternVM.Logger) do
      defmodule PatternVM.Logger do
        def log_interaction(_, _, _), do: :ok
      end
    end

    :ok
  end

  test "execute_definition initializes patterns" do
    # Mock the Runtime module to track calls
    original_register = &PatternVM.DSL.Runtime.register_patterns/1
    original_setup = &PatternVM.DSL.Runtime.setup_interactions/1

    # Count call attempts
    register_count = 0
    setup_count = 0

    try do
      # Replace functions with counting versions
      :meck.new(PatternVM.DSL.Runtime, [:passthrough])

      :meck.expect(PatternVM.DSL.Runtime, :register_patterns, fn patterns ->
        register_count = register_count + 1
        original_register.(patterns)
      end)

      :meck.expect(PatternVM.DSL.Runtime, :setup_interactions, fn interactions ->
        setup_count = setup_count + 1
        original_setup.(interactions)
      end)

      # Execute definition
      workflows = PatternVM.DSL.Runtime.execute_definition(SimplePatterns)

      # Verify expected calls and return
      assert :meck.num_calls(PatternVM.DSL.Runtime, :register_patterns, :_) == 1
      assert :meck.num_calls(PatternVM.DSL.Runtime, :setup_interactions, :_) == 1
      assert workflows == [:test_workflow]
    after
      if :meck.validate(PatternVM.DSL.Runtime) do
        :meck.unload(PatternVM.DSL.Runtime)
      end
    end
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

    # Execute the workflow
    context = PatternVM.DSL.Runtime.execute_workflow(ContextWorkflow, :context_test)

    # Verify context contains expected results
    assert Map.has_key?(context, :last_result)
    # From the notify step
    assert context.last_result == %{executed: true}
  end

  test "process_context_vars handles context substitution" do
    # Call the function directly
    test_context = %{value: "test_value", nested: %{key: "nested_value"}}

    # Test simple value
    simple_result =
      PatternVM.DSL.Runtime.process_context_vars(
        {:context, :value},
        test_context
      )

    assert simple_result == "test_value"

    # Test nested in map
    map_result =
      PatternVM.DSL.Runtime.process_context_vars(
        %{key1: "static", key2: {:context, :value}},
        test_context
      )

    assert map_result == %{key1: "static", key2: "test_value"}

    # Test ordinary value (not context)
    normal_result =
      PatternVM.DSL.Runtime.process_context_vars(
        "not_context",
        test_context
      )

    assert normal_result == "not_context"
  end
end
