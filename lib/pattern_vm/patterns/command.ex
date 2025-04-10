defmodule PatternVM.Command do
  @behaviour PatternVM.PatternBehavior

  def pattern_name, do: :command

  def initialize(config) do
    {:ok,
     %{
       commands: Map.get(config, :commands, %{}),
       history: [],
       name: Map.get(config, :name, :command)
     }}
  end

  def handle_interaction(
        :register_command,
        %{name: name, execute_fn: execute_fn, undo_fn: undo_fn},
        state
      ) do
    updated_commands = Map.put(state.commands, name, %{execute: execute_fn, undo: undo_fn})
    new_state = %{state | commands: updated_commands}

    PatternVM.Logger.log_interaction("Command", "register_command", %{name: name})
    {:ok, {:registered, name}, new_state}
  end

  def handle_interaction(:execute, %{command: command_name, args: args}, state) do
    case Map.fetch(state.commands, command_name) do
      {:ok, %{execute: execute_fn}} ->
        result = execute_fn.(args)
        new_history = [{command_name, args, result} | state.history]
        new_state = %{state | history: new_history}

        PatternVM.Logger.log_interaction("Command", "execute", %{
          command: command_name,
          args: args,
          result: result
        })

        {:ok, result, new_state}

      :error ->
        PatternVM.Logger.log_interaction("Command", "error", %{
          error: "Command not found",
          command: command_name
        })

        {:error, "Command not found: #{command_name}", state}
    end
  end

  def handle_interaction(:undo, _params, %{history: []} = state) do
    PatternVM.Logger.log_interaction("Command", "undo_empty", %{})
    {:ok, {:error, "No commands to undo"}, state}
  end

  def handle_interaction(
        :undo,
        _params,
        %{history: [{command_name, args, _result} | rest_history]} = state
      ) do
    case Map.fetch(state.commands, command_name) do
      {:ok, %{undo: undo_fn}} ->
        result = undo_fn.(args)
        new_state = %{state | history: rest_history}

        PatternVM.Logger.log_interaction("Command", "undo", %{
          command: command_name,
          args: args,
          result: result
        })

        {:ok, result, new_state}

      :error ->
        PatternVM.Logger.log_interaction("Command", "error", %{
          error: "Command undo function not found",
          command: command_name
        })

        {:error, "Command undo function not found: #{command_name}", state}
    end
  end

  def handle_interaction(:get_history, _params, state) do
    PatternVM.Logger.log_interaction("Command", "get_history", %{
      count: length(state.history)
    })

    {:ok, state.history, state}
  end
end
