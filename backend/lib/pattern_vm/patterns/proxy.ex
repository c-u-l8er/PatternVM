defmodule PatternVM.Proxy do
  @behaviour PatternVM.PatternBehavior

  def pattern_name, do: :proxy

  def initialize(config) do
    {:ok,
     %{
       services: Map.get(config, :services, %{}),
       access_rules: Map.get(config, :access_rules, %{}),
       cache: %{},
       name: Map.get(config, :name, :proxy)
     }}
  end

  def handle_interaction(:register_service, %{name: name, handler: handler}, state) do
    updated_services = Map.put(state.services, name, handler)
    new_state = %{state | services: updated_services}

    PatternVM.Logger.log_interaction("Proxy", "register_service", %{name: name})
    {:ok, {:registered, name}, new_state}
  end

  def handle_interaction(:set_access_rule, %{service: service, rule: rule_fn}, state) do
    updated_rules = Map.put(state.access_rules, service, rule_fn)
    new_state = %{state | access_rules: updated_rules}

    PatternVM.Logger.log_interaction("Proxy", "set_access_rule", %{service: service})
    {:ok, {:rule_set, service}, new_state}
  end

  def handle_interaction(:request, %{service: service, args: args, context: context}, state) do
    # First check if we have a rule for this service
    access_allowed =
      case Map.fetch(state.access_rules, service) do
        {:ok, rule_fn} -> rule_fn.(context, args)
        # No rule means access is allowed
        :error -> true
      end

    if access_allowed do
      # Check if we have a cached response
      cache_key = {service, args}

      case Map.fetch(state.cache, cache_key) do
        {:ok, cached_result} ->
          PatternVM.Logger.log_interaction("Proxy", "cache_hit", %{
            service: service,
            args: args
          })

          {:ok, cached_result, state}

        :error ->
          # No cache hit, forward to the real service
          case Map.fetch(state.services, service) do
            {:ok, handler} ->
              result = handler.(args)

              # Cache the result
              updated_cache = Map.put(state.cache, cache_key, result)
              new_state = %{state | cache: updated_cache}

              PatternVM.Logger.log_interaction("Proxy", "service_call", %{
                service: service,
                args: args,
                result: result
              })

              {:ok, result, new_state}

            :error ->
              PatternVM.Logger.log_interaction("Proxy", "error", %{
                error: "Service not found",
                service: service
              })

              {:error, "Service not found: #{service}", state}
          end
      end
    else
      PatternVM.Logger.log_interaction("Proxy", "access_denied", %{
        service: service,
        context: context
      })

      {:error, "Access denied to service: #{service}", state}
    end
  end

  def handle_interaction(:clear_cache, _params, state) do
    PatternVM.Logger.log_interaction("Proxy", "clear_cache", %{})

    {:ok, "Cache cleared", %{state | cache: %{}}}
  end
end
