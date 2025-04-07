defmodule PatternVM.ProxyTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Proxy.initialize(%{})
    assert state == %{services: %{}, access_rules: %{}, cache: %{}, name: :proxy}

    # Test with custom config
    {:ok, custom_state} = PatternVM.Proxy.initialize(%{name: :test_proxy})
    assert custom_state == %{services: %{}, access_rules: %{}, cache: %{}, name: :test_proxy}
  end

  test "register_service adds a service handler" do
    # Initialize proxy pattern
    {:ok, state} = PatternVM.Proxy.initialize(%{})
    handler = fn id -> "Widget #{id}" end

    # Register a service
    {:ok, result, new_state} =
      PatternVM.Proxy.handle_interaction(
        :register_service,
        %{name: :get_widget, handler: handler},
        state
      )

    # Verify registration
    assert result == {:registered, :get_widget}
    assert Map.has_key?(new_state.services, :get_widget)
    assert is_function(new_state.services[:get_widget])
  end

  test "set_access_rule adds an access control rule" do
    # Initialize proxy pattern
    {:ok, state} = PatternVM.Proxy.initialize(%{})
    rule = fn context, _args -> context.role == "admin" end

    # Set an access rule
    {:ok, result, new_state} =
      PatternVM.Proxy.handle_interaction(
        :set_access_rule,
        %{service: :delete_widget, rule: rule},
        state
      )

    # Verify rule setting
    assert result == {:rule_set, :delete_widget}
    assert Map.has_key?(new_state.access_rules, :delete_widget)
    assert is_function(new_state.access_rules[:delete_widget])
  end

  test "request with allowed access calls service and caches result" do
    # Initialize proxy with service
    {:ok, state} = PatternVM.Proxy.initialize(%{})
    handler = fn id -> "Widget #{id}" end

    {:ok, _, state_with_service} =
      PatternVM.Proxy.handle_interaction(
        :register_service,
        %{name: :get_widget, handler: handler},
        state
      )

    # Make a request
    {:ok, result, new_state} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{service: :get_widget, args: "123", context: %{}},
        state_with_service
      )

    # Verify service call and caching
    assert result == "Widget 123"
    assert Map.has_key?(new_state.cache, {:get_widget, "123"})
    assert new_state.cache[{:get_widget, "123"}] == "Widget 123"

    # Make the same request again - should use cache
    {:ok, cached_result, _} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{service: :get_widget, args: "123", context: %{}},
        new_state
      )

    assert cached_result == "Widget 123"
  end

  test "request with denied access returns error" do
    # Initialize proxy with service and rule
    {:ok, state} = PatternVM.Proxy.initialize(%{})
    handler = fn id -> "Widget #{id} deleted" end
    rule = fn context, _args -> context.role == "admin" end

    {:ok, _, state_with_service} =
      PatternVM.Proxy.handle_interaction(
        :register_service,
        %{name: :delete_widget, handler: handler},
        state
      )

    {:ok, _, state_with_rule} =
      PatternVM.Proxy.handle_interaction(
        :set_access_rule,
        %{service: :delete_widget, rule: rule},
        state_with_service
      )

    # Make a request with insufficient privileges
    {:error, message, _} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{service: :delete_widget, args: "123", context: %{role: "user"}},
        state_with_rule
      )

    # Verify access denied
    assert message == "Access denied to service: delete_widget"
  end

  test "clear_cache empties the cache" do
    # Initialize proxy with service and a cached request
    {:ok, state} = PatternVM.Proxy.initialize(%{})
    handler = fn id -> "Widget #{id}" end

    {:ok, _, state_with_service} =
      PatternVM.Proxy.handle_interaction(
        :register_service,
        %{name: :get_widget, handler: handler},
        state
      )

    {:ok, _, state_with_cache} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{service: :get_widget, args: "123", context: %{}},
        state_with_service
      )

    # Clear the cache
    {:ok, result, new_state} =
      PatternVM.Proxy.handle_interaction(
        :clear_cache,
        %{},
        state_with_cache
      )

    # Verify cache clearing
    assert result == "Cache cleared"
    assert new_state.cache == %{}
  end

  test "proxy pattern_name returns the expected atom" do
    assert PatternVM.Proxy.pattern_name() == :proxy
  end
end
