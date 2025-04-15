defmodule PatternVM do
  use GenServer

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{patterns: %{}, registry: %{}}, name: name)
  end

  def init(_) do
    # Initial patterns registry
    registry = %{
      singleton: {PatternVM.Singleton, %{}},
      factory: {PatternVM.Factory, %{}},
      builder: {PatternVM.Builder, %{}},
      strategy: {PatternVM.Strategy, %{}}
    }

    # Initialize pattern states
    pattern_states =
      Enum.reduce(registry, %{}, fn {name, {module, config}}, acc ->
        {:ok, state} = module.initialize(config)
        Map.put(acc, name, {module, state})
      end)

    # Ensure PubSub is available before starting Observer
    ensure_pubsub_started()

    # Start observer for visualization - with error handling
    observer_pid =
      try do
        case PatternVM.Supervisor.start_child(PatternVM.Observer, topics: ["pattern_logs"]) do
          {:ok, pid} -> pid
          _error -> nil
        end
      rescue
        _ -> nil
      end

    PatternVM.Logger.log_interaction("PatternVM", "initialized", %{
      patterns: Map.keys(registry),
      observer_pid: inspect(observer_pid)
    })

    {:ok, %{patterns: pattern_states, registry: registry}}
  end

  # Helper to ensure PubSub is started
  defp ensure_pubsub_started do
    case Process.whereis(PatternVM.PubSub.Supervisor) do
      nil ->
        # PubSub not started yet, start it
        {:ok, _} = PatternVM.PubSub.start_link()

      _ ->
        :ok
    end
  end

  # Client API for pattern interactions
  def interact(pattern_name, action, params \\ %{}) do
    GenServer.call(__MODULE__, {:interact, pattern_name, action, params})
  end

  # Dynamic pattern registration
  def register_pattern(pattern_module, config \\ %{}) do
    GenServer.call(__MODULE__, {:register_pattern, pattern_module, config})
  end

  # Create a product via the Factory pattern
  def create_product(type) do
    interact(:factory, :create_product, %{type: type})
  end

  # Get the singleton instance
  def get_singleton() do
    interact(:singleton, :get_instance)
  end

  # Add an observer for a topic
  def add_observer(topic, callback \\ nil) do
    {:ok, observer_pid} = PatternVM.Supervisor.start_child(PatternVM.Observer, topics: [topic])

    if callback do
      GenServer.call(observer_pid, {:subscribe, %{topic: topic, callback: callback}})
    end

    observer_pid
  end

  # Notify all observers on a topic
  def notify_observers(topic, data) do
    PatternVM.PubSub.broadcast(topic, {:update, Map.put(data, :topic, topic)})
  end

  # Build a complex product using the Builder pattern
  def build_complex_product(params) do
    interact(:builder, :build_step_by_step, params)
  end

  # Register a strategy
  def register_strategy(name, function) do
    interact(:strategy, :register_strategy, %{name: name, function: function})
  end

  # Execute a strategy
  def execute_strategy(name, args) do
    interact(:strategy, :execute_strategy, %{name: name, args: args})
  end

  # Visualize the pattern interaction network
  def get_visualization_data() do
    # Subscribe to logs and then return recent entries
    # In a real application, this would use a storage mechanism
    GenServer.call(__MODULE__, :get_visualization_data)
  end

  # Server Callbacks
  def handle_call({:interact, pattern_name, action, params}, _from, state) do
    case Map.fetch(state.patterns, pattern_name) do
      {:ok, {module, pattern_state}} ->
        case module.handle_interaction(action, params, pattern_state) do
          {:ok, result, new_pattern_state} ->
            updated_patterns = Map.put(state.patterns, pattern_name, {module, new_pattern_state})
            {:reply, result, %{state | patterns: updated_patterns}}

          {:error, reason, new_pattern_state} ->
            updated_patterns = Map.put(state.patterns, pattern_name, {module, new_pattern_state})
            {:reply, {:error, reason}, %{state | patterns: updated_patterns}}
        end

      :error ->
        PatternVM.Logger.log_interaction("PatternVM", "error", %{
          error: "Pattern not found",
          pattern_name: pattern_name
        })

        {:reply, {:error, "Pattern not found: #{pattern_name}"}, state}
    end
  end

  def handle_call({:register_pattern, pattern_module, config}, _from, state) do
    pattern_name = Map.get(config, :name, pattern_module.pattern_name())

    # Initialize the pattern
    {:ok, pattern_state} = pattern_module.initialize(config)

    # Update registry and pattern states
    updated_registry = Map.put(state.registry, pattern_name, {pattern_module, config})
    updated_patterns = Map.put(state.patterns, pattern_name, {pattern_module, pattern_state})

    PatternVM.Logger.log_interaction("PatternVM", "register_pattern", %{
      pattern_name: pattern_name,
      module: inspect(pattern_module)
    })

    {:reply, {:ok, pattern_name},
     %{
       registry: updated_registry,
       patterns: updated_patterns
     }}
  end

  def handle_call(:get_visualization_data, _from, state) do
    # In a real application, this would fetch from a database or in-memory store
    # Here we just return pattern information
    visualization = %{
      patterns: Map.keys(state.patterns),
      connections: [
        %{from: :factory, to: :observer, type: "notification"},
        %{from: :patternvm, to: :factory, type: "creation"},
        %{from: :patternvm, to: :singleton, type: "access"}
      ]
    }

    {:reply, visualization, state}
  end

  def handle_call(:get_patterns, _from, state) do
    patterns = Enum.map(state.patterns, fn {name, {module, _state}} ->
      %{
        name: name,
        type: module.pattern_name()
      }
    end)
    {:reply, patterns, state}
  end

  def handle_call({:get_pattern, pattern_name}, _from, state) do
    case Map.fetch(state.patterns, pattern_name) do
      {:ok, {module, pattern_state}} ->
        pattern_info = %{
          name: pattern_name,
          type: module.pattern_name(),
          state: pattern_state
        }
        {:reply, {:ok, pattern_info}, state}
      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def get_registered_patterns do
    GenServer.call(__MODULE__, :get_patterns)
  end

  def get_pattern(pattern_name) do
    pattern_name_atom =
      case pattern_name do
        name when is_atom(name) -> name
        name when is_binary(name) -> String.to_atom(name)
      end
    GenServer.call(__MODULE__, {:get_pattern, pattern_name_atom})
  end
end
