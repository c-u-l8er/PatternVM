defmodule PatternVM.DSL.ContextTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      {:ok, _} = PatternVM.start_link([])
    end

    :ok
  end

  test "context variable usage in workflows" do
    # Create calculator module directly
    defmodule Calculator do
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

    # Register calculator directly
    PatternVM.register_pattern(Calculator)

    # Create a workflow directly without DSL macros
    workflow = {:sequence, [
      {:store, :a, 10},
      {:store, :b, 5},
      {:interact, :calculator, :add, %{a: {:context, :a}, b: {:context, :b}}},
      {:store, :sum, :last_result}
    ]}

    # Execute the workflow directly
    result = PatternVM.DSL.Runtime.execute_workflow_steps(workflow, %{})

    # Check results
    assert result.a == 10
    assert result.b == 5
    assert result.sum == 15
  end

  test "initial context with workflow execution" do
    # Create a singleton directly
    defmodule Greeter do
      @behaviour PatternVM.PatternBehavior
      def pattern_name, do: :greeter
      def initialize(_), do: {:ok, %{instance: "Hello"}}
      def handle_interaction(:get_instance, _, state), do: {:ok, state.instance, state}
    end

    # Register it
    PatternVM.register_pattern(Greeter)

    # Define workflow steps directly
    workflow = {:sequence, [
      {:interact, :greeter, :get_instance, %{}},
      {:store, :greeting, :last_result}
    ]}

    # Run workflow with initial context
    initial_context = %{name: "World"}
    result = PatternVM.DSL.Runtime.execute_workflow_steps(workflow, initial_context)

    # Verify results
    assert result.greeting == "Hello"
    assert result.name == "World"

    # Test combined values
    combined = "#{result.greeting}, #{result.name}!"
    assert combined == "Hello, World!"
  end

  test "nested context references" do
    # Create the workflow steps directly
    workflow = {:sequence, [
      # Store complex data structure
      {:store, :user, %{
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

      # Access nested values with transform
      {:transform, :theme,
       fn ctx ->
         get_in(ctx.user, [:profile, :settings, :theme])
       end},

      # Access array value with transform
      {:transform, :permission,
       fn ctx ->
         Enum.at(ctx.user.permissions, 0)
       end},

      # Create summary with transform
      {:transform, :summary,
       fn ctx ->
         "User #{ctx.user.profile.name} has #{ctx.permission} permission and uses #{ctx.theme} theme"
       end}
    ]}

    # Execute workflow directly
    result = PatternVM.DSL.Runtime.execute_workflow_steps(workflow, %{})

    # Check results
    assert result.theme == "dark"
    assert result.permission == "read"
    assert result.summary == "User Test User has read permission and uses dark theme"
  end
end
