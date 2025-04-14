defmodule PatternVM.CommandTest do
  use ExUnit.Case

  setup do
    {:ok, state} = PatternVM.Command.initialize(%{})
    %{state: state}
  end

  test "registers and executes a command", %{state: state} do
    # Define command functions
    execute_fn = fn args -> %{action: :created, id: args[:id], data: "Created data"} end
    undo_fn = fn args -> %{action: :deleted, id: args[:id]} end

    # Register command
    {:ok, {:registered, :create_item}, new_state} =
      PatternVM.Command.handle_interaction(
        :register_command,
        %{name: :create_item, execute_fn: execute_fn, undo_fn: undo_fn},
        state
      )

    # Execute command
    {:ok, result, state_after_execute} =
      PatternVM.Command.handle_interaction(
        :execute,
        %{command: :create_item, args: %{id: "123"}},
        new_state
      )

    assert result.action == :created
    assert result.id == "123"

    # Command should be in history
    assert length(state_after_execute.history) == 1
    {cmd_name, cmd_args, cmd_result} = hd(state_after_execute.history)
    assert cmd_name == :create_item
    assert cmd_args.id == "123"
    assert cmd_result == result
  end

  test "undoes the last command", %{state: state} do
    # Define command functions
    execute_fn = fn args -> %{action: :created, id: args[:id]} end
    undo_fn = fn args -> %{action: :deleted, id: args[:id]} end

    # Register and execute command
    {:ok, _, state_with_command} =
      PatternVM.Command.handle_interaction(
        :register_command,
        %{name: :create_item, execute_fn: execute_fn, undo_fn: undo_fn},
        state
      )

    {:ok, _, state_after_execute} =
      PatternVM.Command.handle_interaction(
        :execute,
        %{command: :create_item, args: %{id: "123"}},
        state_with_command
      )

    # Undo command
    {:ok, undo_result, state_after_undo} =
      PatternVM.Command.handle_interaction(
        :undo,
        %{},
        state_after_execute
      )

    assert undo_result.action == :deleted
    assert undo_result.id == "123"

    # Command should be removed from history
    assert state_after_undo.history == []
  end

  test "returns error for unknown command", %{state: state} do
    {:error, message, ^state} =
      PatternVM.Command.handle_interaction(
        :execute,
        %{command: :unknown_command, args: %{}},
        state
      )

    assert message =~ "Command not found"
  end

  test "returns error when undoing with empty history", %{state: state} do
    {:ok, result, ^state} =
      PatternVM.Command.handle_interaction(
        :undo,
        %{},
        state
      )

    assert match?({:error, "No commands to undo"}, result)
  end

  test "executes multiple commands in sequence", %{state: state} do
    # Define commands
    create_fn = fn args -> %{created: args.name} end
    delete_fn = fn args -> %{deleted: args.name} end

    update_fn = fn args -> %{updated: args.name, value: args.value} end
    revert_fn = fn args -> %{reverted: args.name} end

    # Register commands
    {:ok, _, state1} =
      PatternVM.Command.handle_interaction(
        :register_command,
        %{name: :create, execute_fn: create_fn, undo_fn: delete_fn},
        state
      )

    {:ok, _, state2} =
      PatternVM.Command.handle_interaction(
        :register_command,
        %{name: :update, execute_fn: update_fn, undo_fn: revert_fn},
        state1
      )

    # Execute commands
    {:ok, _, state3} =
      PatternVM.Command.handle_interaction(
        :execute,
        %{command: :create, args: %{name: "item1"}},
        state2
      )

    {:ok, _, state4} =
      PatternVM.Command.handle_interaction(
        :execute,
        %{command: :update, args: %{name: "item1", value: "new value"}},
        state3
      )

    # Get history
    {:ok, history, ^state4} =
      PatternVM.Command.handle_interaction(
        :get_history,
        %{},
        state4
      )

    # Verify history has both commands in reverse order (most recent first)
    assert length(history) == 2
    {cmd1, args1, _} = Enum.at(history, 0)
    {cmd2, args2, _} = Enum.at(history, 1)

    assert cmd1 == :update
    assert args1.name == "item1"
    assert cmd2 == :create
    assert args2.name == "item1"

    # Undo last command (update)
    {:ok, undo_result1, state5} =
      PatternVM.Command.handle_interaction(
        :undo,
        %{},
        state4
      )

    assert undo_result1.reverted == "item1"

    # Undo first command (create)
    {:ok, undo_result2, state6} =
      PatternVM.Command.handle_interaction(
        :undo,
        %{},
        state5
      )

    assert undo_result2.deleted == "item1"

    # History should be empty
    assert state6.history == []
  end
end
