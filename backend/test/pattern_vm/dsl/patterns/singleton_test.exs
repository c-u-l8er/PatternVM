defmodule PatternVM.DSL.SingletonTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "singleton pattern definition and usage" do
    defmodule SingletonExample do
      use PatternVM.DSL

      # Define singleton with a simple value
      singleton(:basic_singleton, %{instance: "Basic Singleton"})

      # Define singleton with a map
      singleton(:config_singleton, %{
        instance: %{
          app_name: "PatternVM Test",
          version: "1.0",
          debug: true
        }
      })

      # Define workflow to get instance
      workflow(
        :get_basic,
        sequence([
          {:interact, :basic_singleton, :get_instance, %{}}
        ])
      )

      # Define workflow to get config
      workflow(
        :get_config,
        sequence([
          {:interact, :config_singleton, :get_instance, %{}}
        ])
      )
    end

    # Execute definition
    SingletonExample.execute()

    # Test direct interaction
    result1 = PatternVM.interact(:basic_singleton, :get_instance)
    assert result1 == "Basic Singleton"

    # Test workflow execution
    result2 = PatternVM.DSL.Runtime.execute_workflow(SingletonExample, :get_basic)
    assert result2.last_result == "Basic Singleton"

    # Test config singleton
    result3 = PatternVM.DSL.Runtime.execute_workflow(SingletonExample, :get_config)
    assert result3.last_result.app_name == "PatternVM Test"
    assert result3.last_result.version == "1.0"
    assert result3.last_result.debug == true
  end

  test "multiple singleton instances" do
    defmodule MultipleSingletons do
      use PatternVM.DSL

      # Define multiple singletons
      singleton(:first, %{instance: "First Instance"})
      singleton(:second, %{instance: "Second Instance"})
      singleton(:third, %{instance: "Third Instance"})

      # Workflow that gets all three instances
      workflow(
        :get_all,
        sequence([
          {:interact, :first, :get_instance, %{}},
          # Store first result
          {:store, :first_result, :last_result},
          {:interact, :second, :get_instance, %{}},
          # Store second result
          {:store, :second_result, :last_result},
          {:interact, :third, :get_instance, %{}},
          # Store third result
          {:store, :third_result, :last_result}
        ])
      )
    end

    # Execute definition
    MultipleSingletons.execute()

    # Run workflow to get all instances
    result = PatternVM.DSL.Runtime.execute_workflow(MultipleSingletons, :get_all)

    # Check all values were stored in context
    assert result.first_result == "First Instance"
    assert result.second_result == "Second Instance"
    assert result.third_result == "Third Instance"
  end
end
