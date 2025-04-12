defmodule PatternVM.DSL.CommandTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  # Command implementations
  defmodule TestCommands do
    def add(args), do: %{result: args.a + args.b, operation: :add}
    def undo_add(args), do: %{message: "Undid addition of #{args.a} and #{args.b}"}

    def multiply(args), do: %{result: args.a * args.b, operation: :multiply}
    def undo_multiply(args), do: %{message: "Undid multiplication of #{args.a} and #{args.b}"}
  end

  test "command pattern definition and execution" do
    defmodule CommandExample do
      use PatternVM.DSL
      import PatternVM.DSL.CommandTest.TestCommands, only: []

      # Define command pattern with commands
      command(:calculator, %{
        add: %{
          execute: &PatternVM.DSL.CommandTest.TestCommands.add/1,
          undo: &PatternVM.DSL.CommandTest.TestCommands.undo_add/1
        },
        multiply: %{
          execute: &PatternVM.DSL.CommandTest.TestCommands.multiply/1,
          undo: &PatternVM.DSL.CommandTest.TestCommands.undo_multiply/1
        }
      })

      # Define workflow for executing add command
      workflow(
        :execute_add,
        sequence([
          execute_command(:calculator, :add, %{a: 5, b: 3})
        ])
      )

      # Define workflow for executing multiply command
      workflow(
        :execute_multiply,
        sequence([
          execute_command(:calculator, :multiply, %{a: 4, b: 7})
        ])
      )

      # Define workflow for executing and then undoing command
      workflow(
        :execute_and_undo,
        sequence([
          execute_command(:calculator, :add, %{a: 10, b: 20}),
          {:store, :add_result, :last_result},
          undo_command(:calculator)
        ])
      )
    end

    # Execute definition
    CommandExample.execute()

    # Test add command
    result1 = PatternVM.DSL.Runtime.execute_workflow(CommandExample, :execute_add)
    assert result1.last_result.result == 8
    assert result1.last_result.operation == :add

    # Test multiply command
    result2 = PatternVM.DSL.Runtime.execute_workflow(CommandExample, :execute_multiply)
    assert result2.last_result.result == 28
    assert result2.last_result.operation == :multiply

    # Test execute and undo
    result3 = PatternVM.DSL.Runtime.execute_workflow(CommandExample, :execute_and_undo)
    assert result3.add_result.result == 30
    assert result3.last_result.message =~ "Undid addition"
  end

  test "command history and multiple undos" do
    defmodule CommandHistoryExample do
      use PatternVM.DSL
      import PatternVM.DSL.CommandTest.TestCommands, only: []

      # Define calculator with commands
      command(:multi_calculator, %{
        add: %{
          execute: &PatternVM.DSL.CommandTest.TestCommands.add/1,
          undo: &PatternVM.DSL.CommandTest.TestCommands.undo_add/1
        },
        multiply: %{
          execute: &PatternVM.DSL.CommandTest.TestCommands.multiply/1,
          undo: &PatternVM.DSL.CommandTest.TestCommands.undo_multiply/1
        }
      })

      # Execute multiple commands and undo them in sequence
      workflow(
        :multiple_operations,
        sequence([
          # Execute first command
          execute_command(:multi_calculator, :add, %{a: 5, b: 3}),
          {:store, :add_result, :last_result},

          # Execute second command
          execute_command(:multi_calculator, :multiply, %{a: 2, b: 4}),
          {:store, :multiply_result, :last_result},

          # Get history
          {:interact, :multi_calculator, :get_history, %{}},
          {:store, :history, :last_result},

          # Undo last command (multiply)
          undo_command(:multi_calculator),
          {:store, :first_undo, :last_result},

          # Undo first command (add)
          undo_command(:multi_calculator),
          {:store, :second_undo, :last_result}
        ])
      )
    end

    # Execute definition
    CommandHistoryExample.execute()

    # Run workflow with multiple operations
    result = PatternVM.DSL.Runtime.execute_workflow(CommandHistoryExample, :multiple_operations)

    # Check command results
    assert result.add_result.result == 8
    assert result.multiply_result.result == 8

    # Check history - should have 2 commands
    assert length(result.history) == 2

    # Check undo results
    assert result.first_undo.message =~ "Undid multiplication"
    assert result.second_undo.message =~ "Undid addition"
  end
end
