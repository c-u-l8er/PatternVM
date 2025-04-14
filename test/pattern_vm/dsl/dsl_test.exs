defmodule PatternVM.DSLTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started for each test
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "basic pattern definition and registration" do
    defmodule BasicPatterns do
      use PatternVM.DSL

      # Basic pattern definitions using recognized DSL macros
      pattern(:basic_singleton, :singleton, %{instance: "Singleton Value"})
      pattern(:basic_factory, :factory)
    end

    # Execute definition to register patterns
    workflows = BasicPatterns.execute()
    assert is_list(workflows)

    # Get pattern from registry (verify it was registered)
    result = PatternVM.interact(:basic_singleton, :get_instance)
    assert result == "Singleton Value"
  end

  test "singleton pattern macro" do
    defmodule SingletonTest do
      use PatternVM.DSL

      # Only use the singleton macro which is properly defined
      singleton(:test_singleton, %{instance: "Test Singleton"})
    end

    SingletonTest.execute()

    # Test singleton
    result = PatternVM.interact(:test_singleton, :get_instance)
    assert result == "Test Singleton"
  end

  test "simple workflow definition with sequence" do
    defmodule SequenceTest do
      use PatternVM.DSL

      pattern(:config_store, :singleton, %{instance: "Config Value"})

      # Define a workflow with a proper sequence
      workflow(
        :get_config,
        {:sequence,
         [
           {:interact, :config_store, :get_instance, %{}}
         ]}
      )
    end

    # Register patterns
    workflows = SequenceTest.execute()
    assert :get_config in workflows

    # Execute the workflow
    result = PatternVM.DSL.Runtime.execute_workflow(SequenceTest, :get_config)
    assert result.last_result == "Config Value"
  end

  test "defining interactions between patterns" do
    defmodule InteractionTest do
      use PatternVM.DSL

      # Define two simple patterns
      pattern(:source, :singleton, %{instance: "Source Data"})
      pattern(:target, :singleton, %{instance: "Target Data"})

      # Define an interaction
      interaction(:source, :get_instance, :target, nil)

      # Define workflow that gets data from source
      workflow(
        :get_source_data,
        {:sequence,
         [
           {:interact, :source, :get_instance, %{}}
         ]}
      )
    end

    # Execute definition
    InteractionTest.execute()

    # Test workflow
    result = PatternVM.DSL.Runtime.execute_workflow(InteractionTest, :get_source_data)
    assert result.last_result == "Source Data"
  end

  test "workflow with multiple steps" do
    defmodule MultiStepTest do
      use PatternVM.DSL

      pattern(:factory, :factory)

      # Define a sequence workflow with multiple steps
      workflow(:create_and_transform, {:sequence,
       [
         # Create a product
         {:interact, :factory, :create_product, %{type: :widget}},
         # Create another product
         {:interact, :factory, :create_product, %{type: :gadget}}
       ]})
    end

    # Register patterns
    workflows = MultiStepTest.execute()
    assert :create_and_transform in workflows

    # Execute the workflow
    result = PatternVM.DSL.Runtime.execute_workflow(MultiStepTest, :create_and_transform)
    # Last result should be a gadget
    assert result.last_result.type == :gadget
  end

  # Define transform functions at the module level
  def transform_widget(widget), do: %{widget | name: "Transformed Widget"}

  test "sequence macro works correctly" do
    defmodule SequenceMacroTest do
      use PatternVM.DSL

      pattern(:factory, :factory)

      # Use the sequence macro helper
      workflow(
        :product_workflow,
        sequence([
          {:interact, :factory, :create_product, %{type: :widget}}
        ])
      )
    end

    # Register patterns
    SequenceMacroTest.execute()

    # Execute workflow
    result = PatternVM.DSL.Runtime.execute_workflow(SequenceMacroTest, :product_workflow)
    assert result.last_result.type == :widget
  end

  test "parallel macro works correctly" do
    defmodule ParallelMacroTest do
      use PatternVM.DSL

      pattern(:factory, :factory)

      # Use the parallel macro helper
      workflow(
        :parallel_products,
        parallel([
          {:interact, :factory, :create_product, %{type: :widget}},
          {:interact, :factory, :create_product, %{type: :gadget}}
        ])
      )
    end

    # Register patterns
    ParallelMacroTest.execute()

    # Execute workflow
    result = PatternVM.DSL.Runtime.execute_workflow(ParallelMacroTest, :parallel_products)
    assert length(result.parallel_results) == 2

    # Verify both product types are created
    types = Enum.map(result.parallel_results, fn p -> p.type end)
    assert :widget in types
    assert :gadget in types
  end
end
