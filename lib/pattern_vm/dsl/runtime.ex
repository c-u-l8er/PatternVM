defmodule PatternVM.DSL.Runtime do
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
        {:ok, _} = PatternVM.start_link([])

      _pid ->
        :ok
    end
  end

  defp register_patterns(patterns) do
    Enum.each(patterns, fn {name, type, config} ->
      register_pattern_by_type(name, type, config)
    end)
  end

  defp register_pattern_by_type(name, type, config) do
    module =
      case type do
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

    # Register with config including name
    config_with_name = Map.put(config, :name, name)
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
      case execute_step(step, acc_context) do
        {:store, key, value} ->
          Map.put(acc_context, key, value)

        result ->
          Map.put(acc_context, :last_result, result)
      end
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

  # Handle :store operations differently to directly update the context
  defp execute_step({:store, key, source}, context) do
    value =
      case source do
        :last_result -> Map.get(context, :last_result)
        {:context, path} when is_list(path) -> get_in(context, path)
        {:context, key} -> Map.get(context, key)
        other -> other
      end

    {:store, key, value}
  end

  # Transform operation that executes a function on the context
  defp execute_step({:transform, key, transform_fn}, context) when is_function(transform_fn, 1) do
    result = transform_fn.(context)
    {:store, key, result}
  end

  # Transform operation that accesses a nested path in the context
  defp execute_step({:transform, key, {:context, path}}, context) when is_list(path) do
    value = get_in(context, path)
    {:store, key, value}
  end

  # Transform with variadic path components
  defp execute_step({:transform, key, {:context, key_head, key_tail}}, context) do
    value = context |> Map.get(key_head) |> Map.get(key_tail)
    {:store, key, value}
  end

  defp execute_step({:transform, key, {:context, key_head, key_tail, key_more}}, context) do
    value = context |> Map.get(key_head) |> Map.get(key_tail) |> Map.get(key_more)
    {:store, key, value}
  end

  defp execute_step(
         {:transform, key, {:context, key_head, key_tail, key_more, key_last}},
         context
       ) do
    value =
      context |> Map.get(key_head) |> Map.get(key_tail) |> Map.get(key_more) |> Map.get(key_last)

    {:store, key, value}
  end

  defp process_context_vars(params, context) when is_map(params) do
    Enum.reduce(params, %{}, fn {k, v}, acc ->
      Map.put(acc, k, process_context_vars(v, context))
    end)
  end

  defp process_context_vars({:context, key}, context) do
    Map.get(context, key)
  end

  # Support for nested context references with two levels
  defp process_context_vars({:context, key, path_key}, context) do
    value = Map.get(context, key)
    if is_map(value), do: Map.get(value, path_key), else: nil
  end

  # Support for nested context references with list path
  defp process_context_vars({:context, key, path_key, path_more}, context) do
    value = Map.get(context, key)
    if is_map(value), do: value |> Map.get(path_key) |> Map.get(path_more), else: nil
  end

  # Support for deeper nested paths
  defp process_context_vars({:context, key, path_key, path_more, path_last}, context) do
    value = Map.get(context, key)

    if is_map(value),
      do: value |> Map.get(path_key) |> Map.get(path_more) |> Map.get(path_last),
      else: nil
  end

  # Support for array indexing in context
  defp process_context_vars({:context, key, index}, context) when is_integer(index) do
    value = Map.get(context, key)
    if is_list(value), do: Enum.at(value, index), else: nil
  end

  defp process_context_vars(list, context) when is_list(list) do
    Enum.map(list, &process_context_vars(&1, context))
  end

  defp process_context_vars(value, _context) do
    value
  end
end
