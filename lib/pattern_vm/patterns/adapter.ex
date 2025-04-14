defmodule PatternVM.Adapter do
  @behaviour PatternVM.PatternBehavior

  def pattern_name, do: :adapter

  def initialize(config) do
    adapters =
      config
      |> Map.get(:adapters, %{})
      |> Enum.map(fn
        # Convert MFA tuples to actual functions
        {key, {mod, fun, arity}} when is_atom(mod) and is_atom(fun) and is_integer(arity) ->
          {key, fn arg -> apply(mod, fun, [arg]) end}
        {key, value} ->
          {key, value}
      end)
      |> Enum.into(%{})

    {:ok,
     %{
       adapters: adapters,
       name: Map.get(config, :name, :adapter)
     }}
  end

  def handle_interaction(:register_adapter, %{for_type: type, adapter_fn: adapter_fn}, state) do
    updated_adapters = Map.put(state.adapters, type, adapter_fn)
    new_state = %{state | adapters: updated_adapters}

    PatternVM.Logger.log_interaction("Adapter", "register_adapter", %{type: type})
    {:ok, {:registered, type}, new_state}
  end

  def handle_interaction(:adapt, %{object: object, to_type: target_type}, state) do
    case Map.fetch(state.adapters, target_type) do
      {:ok, adapter_fn} ->
        result = adapter_fn.(object)

        PatternVM.Logger.log_interaction("Adapter", "adapt", %{
          from: object,
          to_type: target_type,
          result: result
        })

        {:ok, result, state}

      :error ->
        PatternVM.Logger.log_interaction("Adapter", "error", %{
          error: "Adapter not found",
          to_type: target_type
        })

        {:error, "Adapter not found for type: #{target_type}", state}
    end
  end
end
