defmodule PatternVM.Strategy do
  @behaviour PatternVM.PatternBehavior

  # Pattern Behavior Implementation
  def pattern_name, do: :strategy

  def initialize(_config), do: {:ok, %{strategies: %{}}}

  def handle_interaction(:register_strategy, %{name: name, function: function}, state) do
    new_state = %{state | strategies: Map.put(state.strategies, name, function)}
    PatternVM.Logger.log_interaction("Strategy", "register", %{strategy_name: name})
    {:ok, {:registered, name}, new_state}
  end

  def handle_interaction(:execute_strategy, %{name: name, args: args}, state) do
    case Map.fetch(state.strategies, name) do
      {:ok, strategy_fn} ->
        result = apply(strategy_fn, [args])

        PatternVM.Logger.log_interaction("Strategy", "execute", %{
          strategy_name: name,
          args: args,
          result: result
        })

        {:ok, result, state}

      :error ->
        PatternVM.Logger.log_interaction("Strategy", "error", %{
          error: "Strategy not found",
          strategy_name: name
        })

        {:error, "Strategy not found: #{name}", state}
    end
  end
end
