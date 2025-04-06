defmodule WidgetFactory do
  use PatternVM.DSL

  # Define patterns
  singleton :config_manager, %{config: %{max_widgets_per_hour: 100}}

  factory :widget_factory, [:widget, :gadget, :tool]

  observer :quality_control, ["products", "errors"]

  builder :widget_builder, ["frame", "display", "battery", "processor"]

  # Use string/atom representations instead of function references
  strategy :pricing_strategy, %{
    standard: :standard_pricing,
    premium: :premium_pricing,
    discount: :discount_pricing
  }

  # Define pricing functions - these will be called by name
  def standard_pricing(product), do: product.base_price
  def premium_pricing(product), do: product.base_price * 1.5
  def discount_pricing(product), do: product.base_price * 0.8

  # Define interactions
  interaction :widget_factory, :create_product, :quality_control, :handle_new_product
  interaction :widget_builder, :build_step_by_step, :pricing_strategy, :price_new_product

  # Define workflows
  workflow :create_widget, sequence([
    create_product(:widget_factory, :widget),
    notify("products", {:context, :last_result}),
    build_product(:widget_builder, "Premium Widget", ["frame", "display", "battery"], %{version: "2.0"})
  ])

  workflow :premium_product_line, sequence([
    parallel([
      create_product(:widget_factory, :widget),
      create_product(:widget_factory, :gadget),
      create_product(:widget_factory, :tool)
    ]),
    build_product(:widget_builder, "Premium Widget", ["frame", "display", "battery", "processor"], %{
      version: "3.0",
      quality: "premium"
    }),
    execute_strategy(:pricing_strategy, :premium, {:context, :last_result})
  ])

  # Handler implementations
  def handle_new_product(product) do
    IO.puts("New product created: #{inspect(product)}")
    product
  end

  def price_new_product(product) do
    base_price = 100 * length(product.parts || [])
    Map.put(product, :base_price, base_price)
  end
end

# Create a Logger module to handle the missing functions
defmodule PatternVM.Logger do
  def log_interaction(source, action, data) do
    IO.puts("[#{source}] #{action}: #{inspect(data)}")
    :ok
  end
end

# Create a Supervisor module for the missing functions
defmodule PatternVM.Supervisor do
  def start_child(module, _args) do
    # Just return a mock PID for demonstration
    {:ok, spawn(fn -> :ok end)}
  end
end

# Create PubSub module
defmodule PatternVM.PubSub do
  def subscribe(_topic) do
    :ok
  end
end

# Complete PatternVM implementation for the example
defmodule PatternVM do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{patterns: %{}, pattern_registry: %{}}, name: __MODULE__)
  end

  def init(state) do
    PatternVM.Logger.log_interaction("PatternVM", "initialized", %{
      state: state
    })
    {:ok, state}
  end

  def register_pattern(pattern_module, config) do
    pattern_name = config[:name]
    PatternVM.Logger.log_interaction("PatternVM", "register_pattern", %{
      pattern_name: pattern_name,
      module: inspect(pattern_module)
    })

    {:ok, state} = pattern_module.initialize(config)

    :ok = GenServer.call(__MODULE__, {:register_pattern, pattern_name, pattern_module, state})
    {:ok, pattern_name}
  end

  def handle_call({:register_pattern, name, module, state}, _from, current_state) do
    updated_patterns = Map.put(current_state.patterns, name, {module, state})
    updated_registry = Map.put(current_state.pattern_registry, name, module)

    {:reply, :ok, %{
      patterns: updated_patterns,
      pattern_registry: updated_registry
    }}
  end

  def handle_call({:interact, pattern_name, action, params}, _from, state) do
    case Map.fetch(state.patterns, pattern_name) do
      {:ok, {module, pattern_state}} ->
        result = mock_interaction_result(pattern_name, action, params)
        {:reply, result, state}

      :error ->
        PatternVM.Logger.log_interaction("PatternVM", "error", %{
          error: "Pattern not found",
          pattern_name: pattern_name
        })
        {:reply, {:error, "Pattern not found: #{pattern_name}"}, state}
    end
  end

  def interact(pattern_name, action, params \\ %{}) do
    PatternVM.Logger.log_interaction("PatternVM", "interact", %{
      pattern: pattern_name,
      action: action,
      params: params
    })

    case GenServer.call(__MODULE__, {:interact, pattern_name, action, params}) do
      {:error, reason} -> {:error, reason}
      result -> result
    end
  end

  def notify_observers(topic, data) do
    Phoenix.PubSub.broadcast(PatternVM.PubSub, topic, {:update, data})
    data
  end

  # Helper to create mock interaction results
  defp mock_interaction_result(pattern_name, action, params) do
    case {pattern_name, action} do
      {_, :create_product} ->
        %{type: params[:type], id: UUID.uuid4(), created_at: DateTime.utc_now()}

      {_, :build_step_by_step} ->
        %{name: params[:name], parts: params[:parts], metadata: params[:metadata]}

      {_, :execute_strategy} ->
        product = params[:args]
        # Apply mock pricing logic based on strategy name
        base_price = 100 * (length(Map.get(product, :parts, [])) + 1)
        price = case params[:name] do
          :premium -> base_price * 1.5
          :discount -> base_price * 0.8
          _ -> base_price
        end
        Map.put(product, :price, price)

      _ ->
        "Response for #{pattern_name}.#{action}"
    end
  end
end

# Phoenix.PubSub implementation for broadcasting
defmodule Phoenix.PubSub do
  def subscribe(_pubsub, topic) do
    IO.puts("Subscribing to #{topic}")
    :ok
  end

  def broadcast(_pubsub, topic, message) do
    IO.puts("Broadcasting to #{topic}: #{inspect(message)}")
    :ok
  end
end

# Add the missing UUID module
defmodule UUID do
  def uuid4() do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> (fn s ->
          String.slice(s, 0, 8) <> "-" <>
            String.slice(s, 8, 4) <> "-" <>
            String.slice(s, 12, 4) <> "-" <>
            String.slice(s, 16, 4) <> "-" <>
            String.slice(s, 20, 12)
        end).()
  end
end

# Runtime module implementation
defmodule PatternVM.DSL.Runtime do
  def execute_definition(module) do
    # Initialize PatternVM if not started
    {:ok, _} = PatternVM.start_link([])

    # Register all patterns
    register_patterns(module.get_patterns())

    # Set up all interactions
    setup_interactions(module.get_interactions())

    # Return workflows that can be executed
    Enum.map(module.get_workflows(), fn {name, _steps} -> name end)
  end

  def execute_workflow(module, workflow_name, initial_context \\ %{}) do
    # Find the workflow
    {^workflow_name, steps} =
      Enum.find(module.get_workflows(), fn {name, _} -> name == workflow_name end)

    # Execute the workflow steps
    execute_steps(steps, initial_context)
  end

  # Private implementation

  defp register_patterns(patterns) do
    Enum.each(patterns, fn {name, type, config} ->
      register_pattern_by_type(name, type, config)
    end)
  end

  defp register_pattern_by_type(name, type, config) do
    module = case type do
      :singleton -> PatternVM.Singleton
      :factory -> PatternVM.Factory
      :observer -> PatternVM.Observer
      :builder -> PatternVM.Builder
      :strategy -> PatternVM.Strategy
    end

    PatternVM.register_pattern(module, Map.merge(%{name: name}, config))
  end

  defp setup_interactions(interactions) do
    Enum.each(interactions, fn {from, action, to, handler} ->
      PatternVM.Logger.log_interaction("DSL", "setup_interaction", %{
        from: from,
        action: action,
        to: to,
        handler: handler
      })
    end)
  end

  defp execute_steps({:sequence, steps}, context) do
    Enum.reduce(steps, context, fn step, acc_context ->
      result = execute_step(step, acc_context)
      Map.merge(acc_context, %{last_result: result})
    end)
  end

  defp execute_steps({:parallel, steps}, context) do
    # Just simulate parallel execution for the example
    results =
      Enum.map(steps, fn step ->
        execute_step(step, context)
      end)

    Map.put(context, :parallel_results, results)
  end

  defp execute_steps(single_step, context) when not is_list(single_step) do
    execute_step(single_step, context)
  end

  defp execute_step({:interact, pattern, action, params}, context) do
    # Replace any context variables in params
    processed_params = process_context_vars(params, context)
    PatternVM.interact(pattern, action, processed_params)
  end

  defp execute_step({:notify, topic, data}, context) do
    processed_data = process_context_vars(data, context)
    PatternVM.notify_observers(topic, processed_data)
  end

  defp execute_step({:sequence, _} = sequence, context) do
    execute_steps(sequence, context)
  end

  defp execute_step({:parallel, _} = parallel, context) do
    execute_steps(parallel, context)
  end

  defp process_context_vars(params, context) when is_map(params) do
    Enum.reduce(params, %{}, fn {k, v}, acc ->
      Map.put(acc, k, process_context_vars(v, context))
    end)
  end

  defp process_context_vars({:context, key}, context) do
    Map.get(context, key)
  end

  defp process_context_vars(value, _context) do
    value
  end
end

# Mock pattern modules
defmodule PatternVM.Singleton do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Factory do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Observer do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Builder do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Strategy do
  def initialize(config), do: {:ok, config}
end

# Example usage module
defmodule PatternVM.DSLExample do
  @moduledoc """
  Examples of using the PatternVM DSL.
  """

  def run_example do
    # Initialize the pattern network from the DSL definition
    WidgetFactory.execute()

    # Execute workflows
    context = PatternVM.DSL.Runtime.execute_workflow(WidgetFactory, :create_widget, %{})
    IO.puts("\nCreate widget result: #{inspect(context)}")

    premium_context = PatternVM.DSL.Runtime.execute_workflow(WidgetFactory, :premium_product_line, %{})
    IO.puts("\nPremium product line result: #{inspect(premium_context)}")
  end
end

# Run the example
PatternVM.DSLExample.run_example()
