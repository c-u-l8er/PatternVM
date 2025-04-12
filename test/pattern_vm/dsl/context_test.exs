defmodule PatternVM.DSL.ContextTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "context variable usage in workflows" do
    defmodule ContextExample do
      use PatternVM.DSL

      # Define a pattern
      pattern(:calculator, :singleton)

      # Define workflow using context variables
      workflow(
        :calculation_flow,
        sequence([
          # Store initial values in context
          {:store, :a, 10},
          {:store, :b, 5},

          # Use context values in parameters
          {:interact, :calculator, :add, %{a: {:context, :a}, b: {:context, :b}}},
          {:store, :sum, :last_result},

          # Use context with transformation
          {:transform, :product, fn ctx -> ctx.a * ctx.b end},

          # Advanced context usage with arithmetic
          {:transform, :complex_result,
           fn ctx ->
             %{
               sum: ctx.sum,
               product: ctx.product,
               difference: ctx.a - ctx.b,
               quotient: ctx.a / ctx.b,
               summary: "The values are #{ctx.a} and #{ctx.b}"
             }
           end}
        ])
      )
    end

    # Create a custom calculator implementation
    defmodule PatternVM.Calculator do
      @behaviour PatternVM.PatternBehavior

      def pattern_name, do: :calculator
      def initialize(_), do: {:ok, %{}}

      def handle_interaction(:add, %{a: a, b: b}, state) do
        {:ok, a + b, state}
      end

      def handle_interaction(:multiply, %{a: a, b: b}, state) do
        {:ok, a * b, state}
      end
    end

    # Register the calculator pattern
    PatternVM.register_pattern(PatternVM.Calculator)

    # Execute definition
    ContextExample.execute()

    # Run the workflow
    result = PatternVM.DSL.Runtime.execute_workflow(ContextExample, :calculation_flow)

    # Check all context values
    assert result.a == 10
    assert result.b == 5
    assert result.sum == 15
    assert result.product == 50
    assert result.complex_result.difference == 5
    assert result.complex_result.quotient == 2.0
    assert result.complex_result.summary == "The values are 10 and 5"
  end

  test "initial context with workflow execution" do
    defmodule InitialContextExample do
      use PatternVM.DSL

      singleton(:greeter, %{instance: "Hello"})

      # Simple workflow that uses context from parameters
      workflow(
        :personalized_greeting,
        sequence([
          {:interact, :greeter, :get_instance, %{}},
          {:transform, :personalized,
           fn ctx ->
             "#{ctx.last_result}, #{ctx.name}!"
           end}
        ])
      )
    end

    # Execute definition
    InitialContextExample.execute()

    # Run workflow with initial context
    result =
      PatternVM.DSL.Runtime.execute_workflow(
        InitialContextExample,
        :personalized_greeting,
        %{name: "World"}
      )

    # Check the result uses the initial context value
    assert result.personalized == "Hello, World!"
  end

  test "nested context references" do
    defmodule NestedContextExample do
      use PatternVM.DSL

      singleton(:data_store)

      # Workflow with deeply nested data
      workflow(
        :nested_data,
        sequence([
          # Store complex nested data
          {:store, :user,
           %{
             id: "123",
             profile: %{
               name: "Test User",
               settings: %{
                 theme: "dark",
                 notifications: true
               }
             },
             permissions: ["read", "write"]
           }},

          # Reference nested values
          {:transform, :theme, {:context, :user, :profile, :settings, :theme}},

          # Reference array item
          {:transform, :permission, {:context, :user, :permissions, 0}},

          # Combine nested values
          {:transform, :summary,
           fn ctx ->
             "User #{ctx.user.profile.name} has #{ctx.permission} permission and uses #{ctx.theme} theme"
           end}
        ])
      )
    end

    # Execute definition
    NestedContextExample.execute()

    # Run the workflow
    result = PatternVM.DSL.Runtime.execute_workflow(NestedContextExample, :nested_data)

    # Check the extracted and transformed values
    assert result.theme == "dark"
    assert result.permission == "read"
    assert result.summary == "User Test User has read permission and uses dark theme"
  end
end
