defmodule PatternVM.CommandTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Command.initialize(%{})
    assert state == %{commands: %{}, history: [], name: :command}

    # Test with custom config
    {:ok, custom_state} = PatternVM.Command.initialize(%{name: :test_command})
    assert custom_state == %{commands: %{}, history: [], name: :test_command}
  end

  test "register_command adds command functions" do
    # Initialize command pattern
    {:ok, state} = PatternVM.Command.initialize(%{})
    execute_fn = fn _args -> %{executed: true} end
    undo_fn = fn _args -> %{undone: true} end

    # Register a command
    {:ok, result, new_state} =
      PatternVM.Command.handle_interaction(
        :register_command,
        %{name: :test_cmd, execute_fn: execute_fn, undo_fn: undo_fn},
        state
      )

    # Verify registration
    assert result == {:registered, :test_cmd}
    assert Map.has_key?(new_state.commands, :test_cmd)
    assert Map.has_key?(new_state.commands[:test_cmd], :execute)
    assert Map.has_key?(new_state.commands[:test_cmd], :undo)
    assert is_function(new_state.commands[:test_cmd][:execute])
    assert is_function(new_state.commands[:test_cmd][:undo])
  end

  test "execute runs a command and records history" do
    # Initialize command pattern
    {:ok, state} = PatternVM.Command.initialize(%{})
    execute_fn = fn args -> %{executed: true, args: args} end
    undo_fn = fn _args -> %{undone: true} end

    # Register and execute a command
    {:ok, _, state_with_cmd} =
      PatternVM.Command.handle_interaction(
        :register_command,
        %{name: :test_cmd, execute_fn: execute_fn, undo_fn: undo_fn},
        state
      )

    args = %{test: true}

    {:ok, result, new_state} =
      PatternVM.Command.handle_interaction(
        :execute,
        %{command: :test_cmd, args: args},
        state_with_cmd
      )

    # Verify execution and history
    assert result.executed == true
    assert result.args == args
    assert length(new_state.history) == 1
    [{cmd_name, cmd_args, cmd_result}] = new_state.history
    assert cmd_name == :test_cmd
    assert cmd_args == args
    assert cmd_result == result
  end

  test "undo reverses the last command" do
    # Setup a command and execute it
    {:ok, state} = PatternVM.Command.initialize(%{})
    execute_fn = fn args -> %{executed: true, args: args} end
    undo_fn = fn args -> %{undone: true, args: args} end

    {:ok, _, state_with_cmd} =
      PatternVM.Command.handle_interaction(
        :register_command,
        %{name: :test_cmd, execute_fn: execute_fn, undo_fn: undo_fn},
        state
      )

    args = %{test: true}

    {:ok, _, state_after_exec} =
      PatternVM.Command.handle_interaction(
        :execute,
        %{command: :test_cmd, args: args},
        state_with_cmd
      )

    # Undo the command
    {:ok, result, new_state} =
      PatternVM.Command.handle_interaction(
        :undo,
        %{},
        state_after_exec
      )

    # Verify undo and history update
    assert result.undone == true
    assert result.args == args
    assert length(new_state.history) == 0
  end

  test "undo with empty history returns error" do
    # Initialize command pattern
    {:ok, state} = PatternVM.Command.initialize(%{})

    # Try to undo with no history
    {:ok, error_result, _} = PatternVM.Command.handle_interaction(:undo, %{}, state)

    # Verify error
    assert error_result == {:error, "No commands to undo"}
  end

  test "command pattern_name returns the expected atom" do
    assert PatternVM.Command.pattern_name() == :command
  end
end
