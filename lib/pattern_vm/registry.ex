defmodule PatternVM.Registry do
  @moduledoc """
  Registry for pattern types and instances.
  """
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{patterns: %{}, instances: %{}}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def register_pattern_type(module) do
    pattern_name = module.pattern_name()
    GenServer.call(__MODULE__, {:register_type, pattern_name, module})
  end

  def register_instance(instance_name, pattern_type, config) do
    GenServer.call(__MODULE__, {:register_instance, instance_name, pattern_type, config})
  end

  def handle_call({:register_type, name, module}, _from, state) do
    updated_patterns = Map.put(state.patterns, name, module)
    {:reply, {:ok, name}, %{state | patterns: updated_patterns}}
  end

  def handle_call({:register_instance, name, type, config}, _from, state) do
    case Map.fetch(state.patterns, type) do
      {:ok, module} ->
        {:ok, pattern_state} = module.initialize(config)

        updated_instances =
          Map.put(
            state.instances,
            name,
            {module, type, pattern_state}
          )

        {:reply, {:ok, name}, %{state | instances: updated_instances}}

      :error ->
        {:reply, {:error, "Unknown pattern type: #{type}"}, state}
    end
  end
end
