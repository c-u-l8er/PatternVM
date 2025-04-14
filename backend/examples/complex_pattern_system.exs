
defmodule ComplexPatternSystem do
  use PatternVM.DSL

  # Define patterns
  singleton :config_manager, %{config: %{max_widgets_per_hour: 100}}

  factory :widget_factory, [:widget, :gadget, :tool]

  # Add missing composite pattern
  composite :widget_catalog

  # Add missing command pattern
  command :widget_commands, %{
    create_widget: %{
      execute: function_ref(ComplexPatternSystem, :create_widget_cmd, 1),
      undo: function_ref(ComplexPatternSystem, :undo_widget_cmd, 1)
    }
  }

  # Define the command handler functions
  def create_widget_cmd(args), do: %{id: "widget-123", created: true, args: args}
  def undo_widget_cmd(_args), do: %{id: "widget-123", deleted: true}

  # Define the handler functions
  def json_to_map(json), do: Jason.decode!(json)
  def map_to_json(map), do: Jason.encode!(map)

  def premium_decorator(widget), do: Map.put(widget, :quality, "premium")
  def discount_decorator(widget), do: Map.put(widget, :price, widget.price * 0.8)

  def get_widget(id), do: "Widget data for #{id}"
  def delete_widget(id), do: "Widget #{id} deleted"

  def validation_can_handle(error), do: error.type == :validation
  def validation_handle(error), do: "Validation error: #{error.message}"

  def db_can_handle(error), do: error.type == :database
  def db_handle(error), do: "Database error: #{error.message}"

  def admin_access_rule(context, _args), do: context.role == "admin"

  # Use function_ref instead of direct function references
  adapter :format_adapter, %{
    json_to_map: function_ref(ComplexPatternSystem, :json_to_map, 1),
    map_to_json: function_ref(ComplexPatternSystem, :map_to_json, 1)
  }

  decorator :widget_decorator, %{
    premium: function_ref(ComplexPatternSystem, :premium_decorator, 1),
    discount: function_ref(ComplexPatternSystem, :discount_decorator, 1)
  }

  proxy :api_proxy, %{
    get_widget: function_ref(ComplexPatternSystem, :get_widget, 1),
    delete_widget: function_ref(ComplexPatternSystem, :delete_widget, 1)
  }, %{
    delete_widget: function_ref(ComplexPatternSystem, :admin_access_rule, 2)
  }

  chain_of_responsibility :error_handler, [
    %{
      name: :validation_error_handler,
      can_handle: function_ref(ComplexPatternSystem, :validation_can_handle, 1),
      handle: function_ref(ComplexPatternSystem, :validation_handle, 1),
      priority: 10
    },
    %{
      name: :db_error_handler,
      can_handle: function_ref(ComplexPatternSystem, :db_can_handle, 1),
      handle: function_ref(ComplexPatternSystem, :db_handle, 1),
      priority: 5
    }
  ]

  # Define workflows
  workflow :create_widget_structure, sequence([
    # Create catalog items
    create_component(:widget_catalog, "cat1", "Base Widgets", :category),
    create_component(:widget_catalog, "cat2", "Premium Widgets", :category),
    create_component(:widget_catalog, "w1", "Basic Widget", :product, %{price: 50}),
    create_component(:widget_catalog, "w2", "Pro Widget", :product, %{price: 100}),

    # Build catalog structure
    add_child(:widget_catalog, "cat1", "w1"),
    add_child(:widget_catalog, "cat2", "w2"),

    # Apply decorators to a widget
    decorate(:widget_decorator, {:context, :last_result}, [:premium]),

    # Execute a command and then undo it
    execute_command(:widget_commands, :create_widget, %{}),
    undo_command(:widget_commands),

    # Adapt data between formats
    adapt(:format_adapter, %{name: "Widget", id: 123}, :map_to_json),

    # Handle errors with chain of responsibility
    process_request(:error_handler, %{type: :validation, message: "Invalid widget type"})
  ])

  workflow :secure_api_access, sequence([
    # Regular user access - allowed
    proxy_request(:api_proxy, :get_widget, "widget-123", %{role: "user"}),

    # Regular user trying to delete - denied
    proxy_request(:api_proxy, :delete_widget, "widget-123", %{role: "user"}),

    # Admin user delete - allowed
    proxy_request(:api_proxy, :delete_widget, "widget-123", %{role: "admin"})
  ])
end

# Mock Jason module for JSON operations
defmodule Jason do
  def decode!(json) when is_binary(json), do: %{data: json, type: "decoded"}
  def encode!(map) when is_map(map), do: "{\"json\":\"#{inspect(map)}\"}"
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

# Complete PatternVM mock implementation
defmodule PatternVM do
  use GenServer

  def start_link(_opts) do
    # Make sure we start with all pattern types registered in the registry
    initial_registry = %{
      singleton: PatternVM.Singleton,
      factory: PatternVM.Factory,
      observer: PatternVM.Observer,
      builder: PatternVM.Builder,
      strategy: PatternVM.Strategy,
      adapter: PatternVM.Adapter,
      decorator: PatternVM.Decorator,
      composite: PatternVM.Composite,
      proxy: PatternVM.Proxy,
      chain_of_responsibility: PatternVM.ChainOfResponsibility,
      command: PatternVM.Command
    }

    GenServer.start_link(__MODULE__, %{
      patterns: %{},
      pattern_registry: initial_registry
    }, name: __MODULE__)
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
    PatternVM.PubSub.broadcast(topic, {:update, Map.put(data, :topic, topic)})
  end

  # Helper to create mock interaction results
  defp mock_interaction_result(pattern_name, action, params) do
    case {pattern_name, action} do
      {:widget_catalog, :create_component} ->
        %{id: params[:id], name: params[:name], type: params[:type], data: params[:data]}

      {:widget_catalog, :add_child} ->
        %{parent_id: params[:parent_id], child_id: params[:child_id], success: true}

      {:widget_decorator, :decorate} ->
        product = params[:object]
        updated =
          if is_map(product) do
            decorators = params[:decorators] || []
            Enum.reduce(decorators, product, fn
              :premium, acc -> Map.put(acc, :quality, "premium")
              :discount, acc ->
                price = Map.get(acc, :price, 100)
                Map.put(acc, :price, price * 0.8)
              _, acc -> acc
            end)
          else
            %{decorated: product, using: params[:decorators]}
          end
        updated

      {:widget_commands, :execute} ->
        %{command: params[:command], success: true, result: "Widget created"}

      {:widget_commands, :undo} ->
        %{success: true, result: "Last command undone"}

      {:format_adapter, :adapt} ->
        case params[:to_type] do
          :map_to_json -> "{\"json\":\"#{inspect(params[:object])}\"}"
          :json_to_map -> %{data: params[:object], converted: true}
          _ -> params[:object]
        end

      {:error_handler, :process_request} ->
        request = params[:request]
        cond do
          request[:type] == :validation ->
            "Validation error: #{request[:message]}"
          request[:type] == :database ->
            "Database error: #{request[:message]}"
          true ->
            "Unknown error: #{inspect(request)}"
        end

      {:api_proxy, :request} ->
        service = params[:service]
        args = params[:args]
        context = params[:context]

        cond do
          service == :delete_widget && context[:role] != "admin" ->
            {:error, "Access denied"}
          service == :get_widget ->
            "Widget data for #{args}"
          service == :delete_widget ->
            "Widget #{args} deleted"
          true ->
            "Unknown service: #{service}"
        end

      _ ->
        "Response for #{pattern_name}.#{action}"
    end
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

defmodule PatternVM.Adapter do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Decorator do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Composite do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Proxy do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.ChainOfResponsibility do
  def initialize(config), do: {:ok, config}
end

defmodule PatternVM.Command do
  def initialize(config), do: {:ok, config}
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

  # Helper to resolve function references
  def resolve_function({:function_ref, module, function, arity}) do
    :erlang.make_fun(module, function, arity)
  end

  def resolve_function({:function_src, source}) do
    # This is a simplified approach - won't work for complex anonymous functions
    {func, _} = Code.eval_string(source)
    func
  end

  def resolve_function(other), do: other

  # Helper to resolve function references in maps
  def resolve_functions_in_map(map) when is_map(map) do
    Enum.into(map, %{}, fn
      {k, {:function_ref, _, _, _} = v} -> {k, resolve_function(v)}
      {k, {:function_src, _} = v} -> {k, resolve_function(v)}
      {k, v} when is_map(v) -> {k, resolve_functions_in_map(v)}
      {k, v} when is_list(v) -> {k, Enum.map(v, &resolve_functions_in_map/1)}
      other -> other
    end)
  end

  def resolve_functions_in_map(list) when is_list(list) do
    Enum.map(list, &resolve_functions_in_map/1)
  end

  def resolve_functions_in_map(other), do: other

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
      :adapter -> PatternVM.Adapter
      :decorator -> PatternVM.Decorator
      :composite -> PatternVM.Composite
      :proxy -> PatternVM.Proxy
      :chain_of_responsibility -> PatternVM.ChainOfResponsibility
      :command -> PatternVM.Command
      _ -> raise "Unknown pattern type: #{type}"
    end

    # Resolve any function references in the config
    resolved_config = resolve_functions_in_map(config)

    # Ensure proper configuration with name
    config_with_name = Map.put(resolved_config, :name, name)
    PatternVM.register_pattern(module, config_with_name)
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

# Demo runner
defmodule PatternVM.ComplexPatternDemo do
  def run do
    IO.puts("\n=== RUNNING COMPLEX PATTERN SYSTEM DEMO ===\n")

    # Initialize patterns from the DSL definition
    workflows = ComplexPatternSystem.execute()

    IO.puts("\nAvailable workflows: #{inspect(workflows)}\n")

    # Execute the widget structure workflow
    IO.puts("\n--- EXECUTING WIDGET STRUCTURE WORKFLOW ---\n")
    structure_results = PatternVM.DSL.Runtime.execute_workflow(ComplexPatternSystem, :create_widget_structure)

    IO.puts("\nWidget Structure Workflow Results:")
    print_results(structure_results)

    # Execute the secure API access workflow
    IO.puts("\n--- EXECUTING SECURE API ACCESS WORKFLOW ---\n")
    api_results = PatternVM.DSL.Runtime.execute_workflow(ComplexPatternSystem, :secure_api_access)

    IO.puts("\nSecure API Access Workflow Results:")
    print_results(api_results)

    IO.puts("\n=== DEMO COMPLETED ===\n")
  end

  defp print_results(results) do
    IO.puts("  Last result: #{inspect(results[:last_result])}")

    if Map.has_key?(results, :parallel_results) do
      IO.puts("  Parallel results:")
      Enum.each(results.parallel_results, fn result ->
        IO.puts("    - #{inspect(result)}")
      end)
    end
  end
end

# Run the demo
PatternVM.ComplexPatternDemo.run()
