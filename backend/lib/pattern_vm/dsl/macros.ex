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
          composite: 1,
          composite: 2,
          proxy: 1,
          proxy: 2,
          proxy: 3,
          chain_of_responsibility: 1,
          chain_of_responsibility: 2,

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

          # Store and transform operations
          store: 2,
          transform: 2,
          transform: 3
        ]

      Module.register_attribute(__MODULE__, :patterns, accumulate: true)
      Module.register_attribute(__MODULE__, :interactions, accumulate: true)
      Module.register_attribute(__MODULE__, :workflows, accumulate: true)
      Module.register_attribute(__MODULE__, :function_placeholders, accumulate: true)
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
        # Store function placeholders for runtime
        placeholders = @function_placeholders

        # Replace placeholders with references to the stored functions
        Enum.map(@workflows, fn {name, steps} ->
          restored_steps = Macro.prewalk(steps, fn
            {:__function_placeholder__, id} = placeholder ->
              # Find the stored function for this placeholder
              {^placeholder, func} = Enum.find(placeholders, fn {ph, _} -> ph == placeholder end)
              # Return a special marker for the runtime to handle
              {:__function__, id, Macro.escape(func)}
            other ->
              other
          end)

          {name, restored_steps}
        end)
      end

      def execute do
        PatternVM.DSL.Runtime.execute_definition(__MODULE__)
      end
    end
  end

  # Define a pattern with its configuration
  defmacro pattern(name, type, config \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, type: type, config: config] do
      @patterns {name, type, config}
    end
  end

  # Define an interaction between patterns
  defmacro interaction(from_pattern, action, to_pattern, result_handler \\ nil) do
    quote bind_quoted: [from_pattern: from_pattern, action: action, to_pattern: to_pattern, result_handler: result_handler] do
      @interactions {from_pattern, action, to_pattern, result_handler}
    end
  end

  # Define a workflow of pattern interactions
  defmacro workflow(name, steps) do
    quote bind_quoted: [name: name, steps: steps] do
      # Convert any anonymous functions to safe representations
      safe_steps = Macro.prewalk(steps, fn
        # Match anonymous functions and convert to placeholders
        {:fn, _, _} = func ->
          # Create a unique placeholder for this function
          placeholder = {:__function_placeholder__, System.unique_integer([:positive])}
          # Store function in module attribute for later retrieval
          Module.put_attribute(__MODULE__, :function_placeholders, {placeholder, func})
          placeholder
        other ->
          other
      end)

      @workflows {name, safe_steps}
    end
  end

  # Store operation
  defmacro store(key, value) do
    safe_value = case value do
      # If it's a map with context references, convert to keyword list
      %{} = map ->
        map_to_kwlist = Enum.map(map, fn {k, v} -> {k, v} end)
        quote do: Map.new(unquote(map_to_kwlist))
      # Otherwise pass through
      other -> other
    end

    quote do
      {:store, unquote(key), unquote(safe_value)}
    end
  end

  # Transform operation
  defmacro transform(key, value) do
    quote bind_quoted: [key: key, value: value] do
      {:transform, key, value}
    end
  end

  defmacro transform(key, source_key, transform_fn) do
    quote bind_quoted: [key: key, source_key: source_key, transform_fn: transform_fn] do
      {:transform, key,
       fn ctx ->
         source_value = Map.get(ctx, source_key)
         transform_fn.(source_value)
       end}
    end
  end

  # Pattern-specific DSL constructs

  # Singleton Pattern
  defmacro singleton(name, config \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, config: config] do
      pattern(name, :singleton, config)
    end
  end

  # Factory Pattern
  defmacro factory(name, products \\ [], config \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, products: products, config: config] do
      pattern_config = Map.merge(config, %{products: products})
      pattern(name, :factory, pattern_config)
    end
  end

  # Observer Pattern
  defmacro observer(name, topics \\ []) do
    quote bind_quoted: [name: name, topics: topics] do
      pattern_config = %{topics: topics}
      pattern(name, :observer, pattern_config)
    end
  end

  # Builder Pattern
  defmacro builder(name, parts \\ [], config \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, parts: parts, config: config] do
      pattern_config = Map.merge(config, %{available_parts: parts})
      pattern(name, :builder, pattern_config)
    end
  end

  # Strategy Pattern
  defmacro strategy(name, strategies \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, strategies: strategies] do
      pattern_config = %{strategies: strategies}
      pattern(name, :strategy, pattern_config)
    end
  end

  # Adapter Pattern
  defmacro adapter(name, adapters \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, adapters: adapters] do
      pattern_config = %{adapters: adapters}
      pattern(name, :adapter, pattern_config)
    end
  end

  # Command Pattern
  defmacro command(name, commands \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, commands: commands] do
      pattern_config = %{commands: commands}
      pattern(name, :command, pattern_config)
    end
  end

  # Decorator Pattern
  defmacro decorator(name, decorators \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, decorators: decorators] do
      pattern_config = %{decorators: decorators}
      pattern(name, :decorator, pattern_config)
    end
  end

  # Composite Pattern
  defmacro composite(name, config \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, config: config] do
      pattern(name, :composite, config)
    end
  end

  # Proxy Pattern
  defmacro proxy(name, services \\ Macro.escape(%{}), access_rules \\ Macro.escape(%{})) do
    quote bind_quoted: [name: name, services: services, access_rules: access_rules] do
      pattern_config = %{
        services: services,
        access_rules: access_rules
      }
      pattern(name, :proxy, pattern_config)
    end
  end

  # Chain of Responsibility Pattern
  defmacro chain_of_responsibility(name, handlers \\ []) do
    quote bind_quoted: [name: name, handlers: handlers] do
      pattern_config = %{handlers: handlers}
      pattern(name, :chain_of_responsibility, pattern_config)
    end
  end

  # Action-specific DSL constructs

  # Factory actions
  defmacro create_product(factory_name, product_type) do
    quote bind_quoted: [factory_name: factory_name, product_type: product_type] do
      {:interact, factory_name, :create_product, %{type: product_type}}
    end
  end

  # Observer actions
  defmacro subscribe(observer_name, topic) do
    quote bind_quoted: [observer_name: observer_name, topic: topic] do
      {:interact, observer_name, :subscribe,
       %{
         topic: topic,
         callback: fn _ -> :ok end
       }}
    end
  end

  defmacro notify(topic, data) do
    quote do
      # Delay all processing to runtime
      {:notify, unquote(topic), unquote(Macro.escape(data))}
    end
  end

  # Helper to convert data to AST that can be safely used in macros
  defp data_to_ast(data) when is_map(data) do
    # Convert map to keyword list for quoting
    pairs = Enum.map(data, fn {k, v} -> {k, data_to_ast(v)} end)
    quote do
      Map.new([unquote_splicing(pairs)])
    end
  end

  defp data_to_ast(data) when is_list(data) do
    quoted_items = Enum.map(data, &data_to_ast/1)
    quote do
      [unquote_splicing(quoted_items)]
    end
  end

  defp data_to_ast({:context, path}) when is_atom(path) do
    quote do
      {:context, unquote(path)}
    end
  end

  defp data_to_ast({:context, key, path}) when is_atom(key) and is_atom(path) do
    quote do
      {:context, unquote(key), unquote(path)}
    end
  end

  defp data_to_ast(data) when is_binary(data) or is_atom(data) or is_number(data) do
    quote do
      unquote(data)
    end
  end

  defp data_to_ast(data) do
    quote do
      unquote(Macro.escape(data))
    end
  end

  # Builder actions
  defmacro build_product(builder_name, name, parts, metadata \\ Macro.escape(%{})) do
    quote bind_quoted: [builder_name: builder_name, name: name, parts: parts, metadata: metadata] do
      {:interact, builder_name, :build_step_by_step,
       %{
         name: name,
         parts: parts,
         metadata: metadata
       }}
    end
  end

  # Strategy actions
  defmacro execute_strategy(strategy_name, name, args) do
    quote bind_quoted: [strategy_name: strategy_name, name: name, args: args] do
      {:interact, strategy_name, :execute_strategy,
       %{
         name: name,
         args: args
       }}
    end
  end

  # Adapter actions
  defmacro adapt(adapter_name, object, to_type) do
    quote bind_quoted: [adapter_name: adapter_name, object: object, to_type: to_type] do
      {:interact, adapter_name, :adapt,
       %{
         object: object,
         to_type: to_type
       }}
    end
  end

  # Command actions
  defmacro execute_command(command_name, command, args) do
    quote bind_quoted: [command_name: command_name, command: command, args: args] do
      {:interact, command_name, :execute,
       %{
         command: command,
         args: args
       }}
    end
  end

  defmacro undo_command(command_name) do
    quote bind_quoted: [command_name: command_name] do
      {:interact, command_name, :undo, %{}}
    end
  end

  # Decorator actions
  defmacro decorate(decorator_name, object, decorators) do
    quote bind_quoted: [decorator_name: decorator_name, object: object, decorators: decorators] do
      {:interact, decorator_name, :decorate,
       %{
         object: object,
         decorators: decorators
       }}
    end
  end

  # Composite actions
  defmacro create_component(composite_name, id, name, type, data \\ Macro.escape(%{})) do
    quote bind_quoted: [composite_name: composite_name, id: id, name: name, type: type, data: data] do
      {:interact, composite_name, :create_component,
       %{
         id: id,
         name: name,
         type: type,
         data: data
       }}
    end
  end

  defmacro add_child(composite_name, parent_id, child_id) do
    quote bind_quoted: [composite_name: composite_name, parent_id: parent_id, child_id: child_id] do
      {:interact, composite_name, :add_child,
       %{
         parent_id: parent_id,
         child_id: child_id
       }}
    end
  end

  # Proxy actions
  defmacro proxy_request(proxy_name, service, args, context \\ Macro.escape(%{})) do
    quote bind_quoted: [proxy_name: proxy_name, service: service, args: args, context: context] do
      {:interact, proxy_name, :request,
       %{
         service: service,
         args: args,
         context: context
       }}
    end
  end

  # Chain of Responsibility actions
  defmacro process_request(chain_name, request) do
    quote bind_quoted: [chain_name: chain_name, request: request] do
      {:interact, chain_name, :process_request,
       %{
         request: request
       }}
    end
  end

  # Workflow control
  defmacro sequence(steps) do
    quote bind_quoted: [steps: steps] do
      {:sequence, steps}
    end
  end

  defmacro parallel(steps) do
    quote bind_quoted: [steps: steps] do
      {:parallel, steps}
    end
  end
end
