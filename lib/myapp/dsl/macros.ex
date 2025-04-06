defmodule PatternVM.DSL do
  @moduledoc """
  Domain-Specific Language for defining and interacting with patterns in PatternVM.

  This DSL allows users to:
  - Define new patterns
  - Configure pattern interactions
  - Compose patterns into networks
  - Execute pattern workflows
  """

  # DSL Macros for Pattern Definition
  defmacro __using__(_opts) do
    quote do
      import PatternVM.DSL
      Module.register_attribute(__MODULE__, :patterns, accumulate: true)
      Module.register_attribute(__MODULE__, :interactions, accumulate: true)
      Module.register_attribute(__MODULE__, :workflows, accumulate: true)
      @before_compile PatternVM.DSL
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def get_patterns, do: @patterns
      def get_interactions, do: @interactions
      def get_workflows, do: @workflows

      def execute do
        PatternVM.DSL.Runtime.execute_definition(__MODULE__)
      end
    end
  end

  # Define a pattern with its configuration
  defmacro pattern(name, type, config \\ quote(do: %{})) do
    quote do
      @patterns {unquote(name), unquote(type), unquote(config)}
    end
  end

  # Define an interaction between patterns
  defmacro interaction(from_pattern, action, to_pattern, result_handler \\ nil) do
    quote do
      @interactions {unquote(from_pattern), unquote(action), unquote(to_pattern),
                     unquote(result_handler)}
    end
  end

  # Define a workflow of pattern interactions
  defmacro workflow(name, steps) do
    quote do
      @workflows {unquote(name), unquote(steps)}
    end
  end

  # Pattern-specific DSL constructs

  # Singleton Pattern
  defmacro singleton(name, config \\ quote(do: %{})) do
    quote do
      pattern(unquote(name), :singleton, unquote(config))
    end
  end

  # Factory Pattern
  defmacro factory(name, products, config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{products: unquote(products)})
      pattern(unquote(name), :factory, merged_config)
    end
  end

  # Observer Pattern
  defmacro observer(name, topics \\ [], config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{topics: unquote(topics)})
      pattern(unquote(name), :observer, merged_config)
    end
  end

  # Builder Pattern
  defmacro builder(name, parts, config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{available_parts: unquote(parts)})
      pattern(unquote(name), :builder, merged_config)
    end
  end

  # Strategy Pattern
  defmacro strategy(name, strategies, config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{strategies: unquote(strategies)})
      pattern(unquote(name), :strategy, merged_config)
    end
  end

  # Adapter Pattern
  defmacro adapter(name, adapters \\ quote(do: %{}), config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{adapters: unquote(adapters)})
      pattern(unquote(name), :adapter, merged_config)
    end
  end

  # Command Pattern
  defmacro command(name, commands \\ quote(do: %{}), config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{commands: unquote(commands)})
      pattern(unquote(name), :command, merged_config)
    end
  end

  # Decorator Pattern
  defmacro decorator(name, decorators \\ quote(do: %{}), config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{decorators: unquote(decorators)})
      pattern(unquote(name), :decorator, merged_config)
    end
  end

  # Composite Pattern
  defmacro composite(name, config \\ quote(do: %{})) do
    quote do
      pattern(unquote(name), :composite, unquote(config))
    end
  end

  # Proxy Pattern
  defmacro proxy(
             name,
             services \\ quote(do: %{}),
             access_rules \\ quote(do: %{}),
             config \\ quote(do: %{})
           ) do
    quote do
      merged_config =
        Map.merge(unquote(config), %{
          services: unquote(services),
          access_rules: unquote(access_rules)
        })

      pattern(unquote(name), :proxy, merged_config)
    end
  end

  # Chain of Responsibility Pattern
  defmacro chain_of_responsibility(name, handlers \\ quote(do: []), config \\ quote(do: %{})) do
    quote do
      merged_config = Map.merge(unquote(config), %{handlers: unquote(handlers)})
      pattern(unquote(name), :chain_of_responsibility, merged_config)
    end
  end

  # Action-specific DSL constructs

  # Factory actions
  defmacro create_product(factory_name, product_type) do
    quote do
      {:interact, unquote(factory_name), :create_product, %{type: unquote(product_type)}}
    end
  end

  # Observer actions
  defmacro subscribe(observer_name, topic) do
    quote do
      {:interact, unquote(observer_name), :subscribe, %{topic: unquote(topic)}}
    end
  end

  defmacro notify(topic, data) do
    quote do
      {:notify, unquote(topic), unquote(data)}
    end
  end

  # Builder actions
  defmacro build_product(builder_name, name, parts, metadata \\ quote(do: %{})) do
    quote do
      {:interact, unquote(builder_name), :build_step_by_step,
       %{
         name: unquote(name),
         parts: unquote(parts),
         metadata: unquote(metadata)
       }}
    end
  end

  # Strategy actions
  defmacro execute_strategy(strategy_name, name, args) do
    quote do
      {:interact, unquote(strategy_name), :execute_strategy,
       %{
         name: unquote(name),
         args: unquote(args)
       }}
    end
  end

  # Adapter actions
  defmacro adapt(adapter_name, object, to_type) do
    quote do
      {:interact, unquote(adapter_name), :adapt,
       %{
         object: unquote(object),
         to_type: unquote(to_type)
       }}
    end
  end

  # Command actions
  defmacro execute_command(command_name, command, args) do
    quote do
      {:interact, unquote(command_name), :execute,
       %{
         command: unquote(command),
         args: unquote(args)
       }}
    end
  end

  defmacro undo_command(command_name) do
    quote do
      {:interact, unquote(command_name), :undo, %{}}
    end
  end

  # Decorator actions
  defmacro decorate(decorator_name, object, decorators) do
    quote do
      {:interact, unquote(decorator_name), :decorate,
       %{
         object: unquote(object),
         decorators: unquote(decorators)
       }}
    end
  end

  # Composite actions
  defmacro create_component(composite_name, id, name, type, data \\ quote(do: %{})) do
    quote do
      {:interact, unquote(composite_name), :create_component,
       %{
         id: unquote(id),
         name: unquote(name),
         type: unquote(type),
         data: unquote(data)
       }}
    end
  end

  defmacro add_child(composite_name, parent_id, child_id) do
    quote do
      {:interact, unquote(composite_name), :add_child,
       %{
         parent_id: unquote(parent_id),
         child_id: unquote(child_id)
       }}
    end
  end

  # Proxy actions
  defmacro proxy_request(proxy_name, service, args, context \\ quote(do: %{})) do
    quote do
      {:interact, unquote(proxy_name), :request,
       %{
         service: unquote(service),
         args: unquote(args),
         context: unquote(context)
       }}
    end
  end

  # Chain of Responsibility actions
  defmacro process_request(chain_name, request) do
    quote do
      {:interact, unquote(chain_name), :process_request,
       %{
         request: unquote(request)
       }}
    end
  end

  # Workflow control
  defmacro sequence(steps) do
    quote do
      {:sequence, unquote(steps)}
    end
  end

  defmacro parallel(steps) do
    quote do
      {:parallel, unquote(steps)}
    end
  end

  # Runtime execution module
  defmodule Runtime do
    @moduledoc """
    Runtime engine for executing PatternVM DSL definitions.
    """

    def execute_definition(module) do
      # Initialize PatternVM if not started
      ensure_pattern_vm_started()

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

    defp ensure_pattern_vm_started do
      case Process.whereis(PatternVM) do
        nil ->
          Application.ensure_all_started(:pattern_vm)

        _pid ->
          :ok
      end
    end

    defp register_patterns(patterns) do
      Enum.each(patterns, fn {name, type, config} ->
        register_pattern_by_type(name, type, config)
      end)
    end

    defp register_pattern_by_type(name, :singleton, config) do
      PatternVM.register_pattern(PatternVM.Singleton, Map.merge(%{name: name}, config))
      PatternVM.interact(name, :initialize)
    end

    defp register_pattern_by_type(name, :factory, config) do
      PatternVM.register_pattern(PatternVM.Factory, Map.merge(%{name: name}, config))

      # Register product types if specified
      if products = config[:products] do
        Enum.each(products, fn product_type ->
          PatternVM.interact(name, :register_product, %{type: product_type})
        end)
      end
    end

    defp register_pattern_by_type(name, :observer, config) do
      PatternVM.register_pattern(PatternVM.Observer, Map.merge(%{name: name}, config))

      # Subscribe to topics if specified
      if topics = config[:topics] do
        Enum.each(topics, fn topic ->
          PatternVM.interact(name, :subscribe, %{topic: topic})
        end)
      end
    end

    defp register_pattern_by_type(name, :builder, config) do
      PatternVM.register_pattern(PatternVM.Builder, Map.merge(%{name: name}, config))
    end

    defp register_pattern_by_type(name, :strategy, config) do
      PatternVM.register_pattern(PatternVM.Strategy, Map.merge(%{name: name}, config))

      # Register strategies if specified
      if strategies = config[:strategies] do
        Enum.each(strategies, fn {strategy_name, function} ->
          PatternVM.interact(name, :register_strategy, %{
            name: strategy_name,
            function: function
          })
        end)
      end
    end

    defp setup_interactions(interactions) do
      Enum.each(interactions, fn {from, action, to, handler} ->
        # Set up the interaction (in a real implementation, this would configure
        # how patterns connect and communicate)
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
      # In a real implementation, this would execute steps concurrently
      # Here we just simulate it sequentially for demonstration
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
end
