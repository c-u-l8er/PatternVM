defmodule PatternVM.DSL.ProxyTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  # Service functions
  defmodule TestServices do
    def get_user(id), do: %{id: id, name: "User #{id}", type: :user}
    def update_user(%{id: id, data: data}), do: %{id: id, updated: true, data: data}
  end

  # Access rules
  defmodule AccessRules do
    def admin_only(context, _args) do
      context[:role] == "admin"
    end
  end

  test "proxy pattern definition and request handling" do
    defmodule ProxyExample do
      use PatternVM.DSL

      # Define proxy with services and access rules using MFA tuples
      proxy(
        :user_proxy,
        %{
          get_user: {PatternVM.DSL.ProxyTest.TestServices, :get_user, 1},
          update_user: {PatternVM.DSL.ProxyTest.TestServices, :update_user, 1}
        },
        %{
          update_user: {PatternVM.DSL.ProxyTest.AccessRules, :admin_only, 2}
        }
      )

      # Define workflow for getting a user (allowed for all)
      workflow(
        :get_user,
        sequence([
          proxy_request(:user_proxy, :get_user, "123", %{role: "user"})
        ])
      )

      # Define workflow for updating a user (allowed only for admin)
      workflow(
        :update_user_as_admin,
        sequence([
          proxy_request(:user_proxy, :update_user, %{id: "123", data: %{name: "New Name"}}, %{
            role: "admin"
          })
        ])
      )

      # Define workflow for updating as a regular user (should be denied)
      workflow(
        :update_user_as_regular,
        sequence([
          proxy_request(:user_proxy, :update_user, %{id: "123", data: %{name: "New Name"}}, %{
            role: "user"
          })
        ])
      )
    end

    # Execute definition
    ProxyExample.execute()

    # Test get user (should succeed)
    result1 = PatternVM.DSL.Runtime.execute_workflow(ProxyExample, :get_user)
    assert result1.last_result.id == "123"
    assert result1.last_result.type == :user

    # Test update as admin (should succeed)
    result2 = PatternVM.DSL.Runtime.execute_workflow(ProxyExample, :update_user_as_admin)
    assert result2.last_result.updated == true

    # Test update as regular user (should fail)
    result3 = PatternVM.DSL.Runtime.execute_workflow(ProxyExample, :update_user_as_regular)
    assert match?({:error, _}, result3.last_result)
  end

  test "proxy caching" do
    defmodule ProxyCachingExample do
      use PatternVM.DSL

      # Define expensive operation function
      def expensive_operation(id) do
        %{
          id: id,
          result: "Expensive result for #{id}",
          timestamp: :os.system_time(:millisecond)
        }
      end

      # Define proxy with a service using MFA tuple
      proxy(:cache_proxy, %{
        expensive_operation: {__MODULE__, :expensive_operation, 1}
      })

      # Define workflow that calls the same service twice
      workflow(
        :call_twice,
        sequence([
          # First call (should execute the actual service)
          proxy_request(:cache_proxy, :expensive_operation, "test", %{}),
          {:store, :first_call, :last_result},

          # Second call with same args (should use cache)
          proxy_request(:cache_proxy, :expensive_operation, "test", %{}),
          {:store, :second_call, :last_result},

          # Clear cache
          {:interact, :cache_proxy, :clear_cache, %{}},

          # Third call after cache clear (should execute again)
          proxy_request(:cache_proxy, :expensive_operation, "test", %{}),
          {:store, :third_call, :last_result}
        ])
      )
    end

    # Execute definition
    ProxyCachingExample.execute()

    # Run the workflow
    result = PatternVM.DSL.Runtime.execute_workflow(ProxyCachingExample, :call_twice)

    # First and second calls should have identical results (cached)
    assert result.first_call == result.second_call
    assert result.first_call.id == "test"

    # Third call should have same data but different timestamp
    assert result.third_call.id == "test"
    assert result.third_call.result == result.first_call.result
  end
end
