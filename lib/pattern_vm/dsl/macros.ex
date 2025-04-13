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
      # Import all pattern definition functions
      import PatternVM.DSL,
        only: [
          pattern: 2,
          pattern: 3,
          singleton: 1,
          singleton: 2,
          factory: 1,
          factory: 2,
          factory: 3,
          builder: 1,
          builder: 2,
          builder: 3,
          strategy: 1,
          strategy: 2,
          strategy: 3,
          adapter: 1,
          adapter: 2,
          adapter: 3,
          observer: 1,
          observer: 2,
          observer: 3,
          decorator: 1,
          decorator: 2,
          decorator: 3,
          command: 1,
          command: 2,
          command: 3,
          composite: 1,
          composite: 2,
          proxy: 1,
          proxy: 2,
          proxy: 3,
          proxy: 4,
          chain_of_responsibility: 1,
          chain_of_responsibility: 2,
          chain_of_responsibility: 3,

          # Action functions
          create_product: 2,
          subscribe: 2,
          notify: 2,
          build_product: 3,
          build_product: 4,
          execute_strategy: 3,
          adapt: 3,
          execute_command: 3,
          undo_command: 1,
          decorate: 3,
          create_component: 4,
          create_component: 5,
          add_child: 3,
          proxy_request: 3,
          proxy_request: 4,
          process_request: 2,

          # Flow constructors
          interaction: 3,
          interaction: 4,
          workflow: 2,
          sequence: 1,
          parallel: 1,

          # Helper functions
          function_ref: 3,
          represent_function: 1,

          # Store and transform operations
          store: 2,
          transform: 2,
          transform: 3
        ]

      Module.register_attribute(__MODULE__, :patterns, accumulate: true)
      Module.register_attribute(__MODULE__, :interactions, accumulate: true)
      Module.register_attribute(__MODULE__, :workflows, accumulate: true)
      @before_compile PatternVM.DSL
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def get_patterns do
        @patterns
      end

      def get_interactions do
        @interactions
      end

      def get_workflows do
        @workflows
      end

      def execute do
        PatternVM.DSL.Runtime.execute_definition(__MODULE__)
      end
    end
  end

  # Define a pattern with its configuration
  defmacro pattern(name, type, config \\ quote(do: %{})) do
    quote do
      pattern_config = unquote(config)
      @patterns {unquote(name), unquote(type), pattern_config}
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

  # Helper to handle function references
  defmacro function_ref(module, function, arity) do
    quote do
      {:function_ref, unquote(module), unquote(function), unquote(arity)}
    end
  end

  # Store operation
  defmacro store(key, value) do
    quote do
      {:store, unquote(key), unquote(value)}
    end
  end

  # Transform operation
  defmacro transform(key, value) do
    quote do
      {:transform, unquote(key), unquote(value)}
    end
  end

  defmacro transform(key, source_key, transform_fn) do
    quote do
      {:transform, unquote(key),
       fn ctx ->
         source_value = Map.get(ctx, unquote(source_key))
         unquote(transform_fn).(source_value)
       end}
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
  defmacro factory(name, products \\ [], config \\ quote(do: %{})) do
    quote do
      pattern_config = Map.merge(unquote(config), %{products: unquote(products)})
      pattern(unquote(name), :factory, pattern_config)
    end
  end

  # Observer Pattern
  defmacro observer(name, topics \\ [], config \\ quote(do: %{})) do
    quote do
      pattern_config = Map.merge(unquote(config), %{topics: unquote(topics)})
      pattern(unquote(name), :observer, pattern_config)
    end
  end

  # Builder Pattern
  defmacro builder(name, parts \\ [], config \\ quote(do: %{})) do
    quote do
      pattern_config = Map.merge(unquote(config), %{available_parts: unquote(parts)})
      pattern(unquote(name), :builder, pattern_config)
    end
  end

  # Strategy Pattern
  defmacro strategy(name, strategies \\ %{}, config \\ quote(do: %{})) do
    quote do
      pattern_config = Map.merge(unquote(config), %{strategies: unquote(strategies)})
      pattern(unquote(name), :strategy, pattern_config)
    end
  end

  # Adapter Pattern
  defmacro adapter(name, adapters \\ quote(do: %{}), config \\ quote(do: %{})) do
    quote do
      processed_adapters = unquote(adapters)
      pattern_config = Map.merge(unquote(config), %{adapters: processed_adapters})
      pattern(unquote(name), :adapter, pattern_config)
    end
  end

  # Helper macro to convert function references
  defmacro represent_function(func) do
    quote do
      case unquote(func) do
        # If it's already a function reference tuple, return it
        {:function_ref, _, _, _} = ref ->
          ref

        # Convert &Mod.fun/arity notation
        {:&, _, [{:/, _, [{:., _, [{:__aliases__, _, mod}, fun]}, _, [arity]]}]} ->
          module = Module.concat(mod)
          {:function_ref, module, fun, arity}

        # Handle anonymous functions by storing as strings to be evaluated later
        # This is a simplified approach - won't work for complex anonymous functions
        _ ->
          {:function_src, Macro.to_string(unquote(func))}
      end
    end
  end

  # Command Pattern
  defmacro command(name, commands \\ quote(do: %{}), config \\ quote(do: %{})) do
    quote do
      pattern_config = Map.merge(unquote(config), %{commands: unquote(commands)})
      pattern(unquote(name), :command, pattern_config)
    end
  end

  # Decorator Pattern
  defmacro decorator(name, decorators \\ quote(do: %{}), config \\ quote(do: %{})) do
    quote do
      pattern_config = Map.merge(unquote(config), %{decorators: unquote(decorators)})
      pattern(unquote(name), :decorator, pattern_config)
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
      pattern_config =
        Map.merge(unquote(config), %{
          services: unquote(services),
          access_rules: unquote(access_rules)
        })

      pattern(unquote(name), :proxy, pattern_config)
    end
  end

  # Chain of Responsibility Pattern
  defmacro chain_of_responsibility(name, handlers \\ quote(do: []), config \\ quote(do: %{})) do
    quote do
      pattern_config = Map.merge(unquote(config), %{handlers: unquote(handlers)})
      pattern(unquote(name), :chain_of_responsibility, pattern_config)
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
      {:interact, unquote(observer_name), :subscribe,
       %{
         topic: unquote(topic),
         callback: fn _ -> :ok end
       }}
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
end
