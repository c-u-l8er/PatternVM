defmodule PatternVM.ProxyTest do
  use ExUnit.Case

  setup do
    # Define test services and rules
    services = %{
      get_data: fn id -> %{id: id, data: "Test data"} end,
      update_data: fn %{id: id, value: value} -> %{id: id, updated: true, value: value} end
    }

    access_rules = %{
      update_data: fn context, _ -> context.role == "admin" end
    }

    {:ok, state} =
      PatternVM.Proxy.initialize(%{
        services: services,
        access_rules: access_rules
      })

    %{state: state}
  end

  test "forwards requests to real service", %{state: state} do
    {:ok, result, _new_state} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{
          service: :get_data,
          args: "123",
          context: %{role: "user"}
        },
        state
      )

    assert result.id == "123"
    assert result.data == "Test data"
  end

  test "caches results", %{state: state} do
    # First request - should execute service and cache
    {:ok, result1, new_state} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{
          service: :get_data,
          args: "123",
          context: %{role: "user"}
        },
        state
      )

    # Second request - should use cache
    {:ok, result2, _} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{
          service: :get_data,
          args: "123",
          context: %{role: "different_user"}
        },
        new_state
      )

    # Results should be identical
    assert result1 == result2

    # Verify cache contains the result
    assert Map.has_key?(new_state.cache, {:get_data, "123"})
  end

  test "enforces access rules", %{state: state} do
    # User tries update - should be denied
    {:error, message, _} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{
          service: :update_data,
          args: %{id: "123", value: "new"},
          context: %{role: "user"}
        },
        state
      )

    assert message =~ "Access denied"

    # Admin tries update - should succeed
    {:ok, result, _} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{
          service: :update_data,
          args: %{id: "123", value: "new"},
          context: %{role: "admin"}
        },
        state
      )

    assert result.updated == true
    assert result.id == "123"
  end

  test "registers new service", %{state: state} do
    new_service = fn -> "New service result" end

    {:ok, {:registered, :new_service}, new_state} =
      PatternVM.Proxy.handle_interaction(
        :register_service,
        %{name: :new_service, handler: new_service},
        state
      )

    # Use the new service
    {:ok, result, _} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{
          service: :new_service,
          args: nil,
          context: %{}
        },
        new_state
      )

    assert result == "New service result"
  end

  test "clears cache", %{state: state} do
    # Make a request to fill cache
    {:ok, _, new_state} =
      PatternVM.Proxy.handle_interaction(
        :request,
        %{
          service: :get_data,
          args: "123",
          context: %{role: "user"}
        },
        state
      )

    # Verify cache has data
    assert new_state.cache != %{}

    # Clear cache
    {:ok, "Cache cleared", cleared_state} =
      PatternVM.Proxy.handle_interaction(
        :clear_cache,
        %{},
        new_state
      )

    # Verify cache is empty
    assert cleared_state.cache == %{}
  end
end
