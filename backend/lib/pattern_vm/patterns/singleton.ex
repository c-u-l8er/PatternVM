defmodule PatternVM.Singleton do
  use GenServer
  @behaviour PatternVM.PatternBehavior

  # Pattern Behavior Implementation
  def pattern_name, do: :singleton

  def initialize(config) do
    instance = Map.get(config, :instance, "I am the Singleton")
    {:ok, %{instance: instance}}
  end

  def handle_interaction(:get_instance, _params, state) do
    PatternVM.Logger.log_interaction("Singleton", "get_instance", %{})
    {:ok, state.instance, state}
  end

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_instance do
    GenServer.call(__MODULE__, :get_instance)
  end

  # Server Callbacks
  def init(:ok) do
    state = %{instance: "I am the Singleton"}
    PatternVM.Logger.log_interaction("Singleton", "initialized", state)
    {:ok, state}
  end

  def handle_call(:get_instance, _from, state) do
    {:reply, state.instance, state}
  end
end
