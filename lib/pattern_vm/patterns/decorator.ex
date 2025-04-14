defmodule PatternVM.Decorator do
  @behaviour PatternVM.PatternBehavior

  def pattern_name, do: :decorator

  def initialize(config) do
    # Process any MFA tuples into actual functions
    decorators = process_decorator_functions(Map.get(config, :decorators, %{}))

    {:ok,
     %{
       decorators: decorators,
       name: Map.get(config, :name, :decorator)
     }}
  end

  # Helper to process MFA tuples into functions
  defp process_decorator_functions(decorators) do
    Enum.map(decorators, fn
      {name, {mod, fun, arity}} when is_atom(mod) and is_atom(fun) and is_integer(arity) ->
        {name, fn arg -> apply(mod, fun, [arg]) end}
      {name, function} when is_function(function) ->
        {name, function}
      entry -> entry
    end)
    |> Enum.into(%{})
  end

  def handle_interaction(:register_decorator, %{name: name, decorator_fn: decorator_fn}, state) do
    # Handle both function and MFA tuple
    processed_fn = case decorator_fn do
      {mod, fun, 1} when is_atom(mod) and is_atom(fun) ->
        fn arg -> apply(mod, fun, [arg]) end
      fn_when_is_function -> fn_when_is_function
    end

    updated_decorators = Map.put(state.decorators, name, processed_fn)
    new_state = %{state | decorators: updated_decorators}

    PatternVM.Logger.log_interaction("Decorator", "register_decorator", %{name: name})
    {:ok, {:registered, name}, new_state}
  end

  def handle_interaction(:decorate, %{object: object, decorators: decorator_names}, state) do
    {result, errors} =
      Enum.reduce(decorator_names, {object, []}, fn decorator_name, {acc_object, acc_errors} ->
        case Map.fetch(state.decorators, decorator_name) do
          {:ok, decorator_fn} ->
            {decorator_fn.(acc_object), acc_errors}

          :error ->
            error = "Decorator not found: #{decorator_name}"
            {acc_object, [error | acc_errors]}
        end
      end)

    if Enum.empty?(errors) do
      PatternVM.Logger.log_interaction("Decorator", "decorate", %{
        original: object,
        decorators: decorator_names,
        result: result
      })

      {:ok, result, state}
    else
      PatternVM.Logger.log_interaction("Decorator", "error", %{
        errors: errors,
        decorators: decorator_names
      })

      {:error, errors, state}
    end
  end
end
