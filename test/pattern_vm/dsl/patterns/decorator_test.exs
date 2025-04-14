defmodule PatternVM.DSL.DecoratorTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  # Decorator functions
  defmodule TestDecorators do
    def add_logger(component) do
      Map.put(component, :logging, true)
    end

    def add_cache(component) do
      Map.put(component, :cached, true)
    end

    def add_metrics(component) do
      Map.put(component, :metrics, true)
    end
  end

  test "decorator pattern definition and usage" do
    defmodule DecoratorExample do
      use PatternVM.DSL

      # Define decorator pattern with decorators using MFA tuples
      decorator(:component_decorator, %{
        logger: {PatternVM.DSL.DecoratorTest.TestDecorators, :add_logger, 1},
        cache: {PatternVM.DSL.DecoratorTest.TestDecorators, :add_cache, 1},
        metrics: {PatternVM.DSL.DecoratorTest.TestDecorators, :add_metrics, 1}
      })

      # Define workflow for applying single decorator
      workflow(
        :add_logging,
        sequence([
          decorate(:component_decorator, %{name: "BasicComponent"}, [:logger])
        ])
      )

      # Define workflow for applying multiple decorators
      workflow(
        :add_multiple,
        sequence([
          decorate(:component_decorator, %{name: "AdvancedComponent"}, [:logger, :cache, :metrics])
        ])
      )
    end

    # Execute definition
    DecoratorExample.execute()

    # Test single decorator
    result1 = PatternVM.DSL.Runtime.execute_workflow(DecoratorExample, :add_logging)
    assert result1.last_result.name == "BasicComponent"
    assert result1.last_result.logging == true
    refute Map.has_key?(result1.last_result, :cached)

    # Test multiple decorators
    result2 = PatternVM.DSL.Runtime.execute_workflow(DecoratorExample, :add_multiple)
    assert result2.last_result.name == "AdvancedComponent"
    assert result2.last_result.logging == true
    assert result2.last_result.cached == true
    assert result2.last_result.metrics == true
  end

  # Define uppercase decorator function at module level
  def uppercase_decorator(obj) do
    Map.update(obj, :text, "", &String.upcase/1)
  end

  test "registering decorators at runtime" do
    defmodule RuntimeDecoratorExample do
      use PatternVM.DSL

      # Define empty decorator pattern
      decorator(:runtime_decorator)

      # Workflow to register a decorator
      workflow(
        :register_decorator,
        sequence([
          {:interact, :runtime_decorator, :register_decorator,
           %{
             name: :uppercase,
             decorator_fn: {PatternVM.DSL.DecoratorTest, :uppercase_decorator, 1}
           }}
        ])
      )

      # Workflow to use the registered decorator
      workflow(
        :apply_registered,
        sequence([
          decorate(:runtime_decorator, %{text: "hello world"}, [:uppercase])
        ])
      )
    end

    # Execute definition
    RuntimeDecoratorExample.execute()

    # Register the decorator
    PatternVM.DSL.Runtime.execute_workflow(RuntimeDecoratorExample, :register_decorator)

    # Apply the registered decorator
    result = PatternVM.DSL.Runtime.execute_workflow(RuntimeDecoratorExample, :apply_registered)
    assert result.last_result.text == "HELLO WORLD"
  end

  test "combining decorators in different orders" do
    defmodule DecoratorOrderExample do
      use PatternVM.DSL

      # Define functions for decorators
      def add_prefix(text), do: "PREFIX: " <> text
      def add_suffix(text), do: text <> " :SUFFIX"
      def emphasize(text), do: "*** " <> text <> " ***"

      # Define decorator pattern with sequential transformations using MFA tuples
      decorator(:text_decorator, %{
        add_prefix: {__MODULE__, :add_prefix, 1},
        add_suffix: {__MODULE__, :add_suffix, 1},
        emphasize: {__MODULE__, :emphasize, 1}
      })

      # Apply decorators in one order
      workflow(
        :order_one,
        sequence([
          decorate(:text_decorator, "Base Text", [:add_prefix, :add_suffix, :emphasize])
        ])
      )

      # Apply decorators in different order
      workflow(
        :order_two,
        sequence([
          decorate(:text_decorator, "Base Text", [:emphasize, :add_prefix, :add_suffix])
        ])
      )
    end

    # Execute definition
    DecoratorOrderExample.execute()

    # Test first order
    result1 = PatternVM.DSL.Runtime.execute_workflow(DecoratorOrderExample, :order_one)
    assert result1.last_result == "*** PREFIX: Base Text :SUFFIX ***"

    # Test second order
    result2 = PatternVM.DSL.Runtime.execute_workflow(DecoratorOrderExample, :order_two)
    assert result2.last_result == "PREFIX: *** Base Text *** :SUFFIX"
  end
end
