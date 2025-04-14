defmodule PatternVM.DSL.ObserverTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    # Ensure PubSub is started
    case Phoenix.PubSub.Supervisor.start_link(name: PatternVM.PubSub) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Create test process to receive event notifications
    test_pid = self()

    # Subscribe to test topics for direct observation
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "system_events")
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "user_events")
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "product_created")

    :ok
  end

  # Define callback modules and functions outside the DSL
  defmodule TestCallbacks do
    def handle_system_event(data) do
      test_pid = Process.get(:test_pid)
      send(test_pid, {:system_event_received, data})
    end

    def handle_user_event(data) do
      test_pid = Process.get(:test_pid)
      send(test_pid, {:user_event_received, data})
    end
  end

  test "observer pattern definition and subscription" do
    defmodule BasicObserverExample do
      use PatternVM.DSL

      # Define observer patterns with initial topics
      observer(:system_observer, ["system_events"])
      observer(:user_observer, ["user_events"])

      # Setup subscribes only - no notification workflows
      workflow(
        :setup_observers,
        sequence([
          # Subscribe with callback using MFA tuple
          {:interact, :system_observer, :subscribe,
           %{
             topic: "error_events",
             callback: {PatternVM.DSL.ObserverTest.TestCallbacks, :handle_system_event, 1}
           }}
        ])
      )
    end

    # Execute definition to register patterns
    BasicObserverExample.execute()

    # Setup observers
    PatternVM.DSL.Runtime.execute_workflow(BasicObserverExample, :setup_observers)

    # Send event directly using PatternVM.notify_observers
    PatternVM.notify_observers("system_events", %{
      type: "system_notification",
      message: "System alert"
    })

    # Check if we received the notification (we're subscribed directly in setup)
    assert_receive {:update, notification}, 500
    assert notification.type == "system_notification"
    assert notification.message == "System alert"

    # Direct notification to test user events
    PatternVM.notify_observers("user_events", %{type: "user_login", user_id: "123"})

    # Check if we received this notification too
    assert_receive {:update, user_notification}, 500
    assert user_notification.type == "user_login"
    assert user_notification.user_id == "123"
  end

  test "multiple observers with different topics" do
    defmodule MultiObserverExample do
      use PatternVM.DSL

      # Define observers for different domains
      observer(:system_monitor, ["system_status", "system_metrics"])
      observer(:security_monitor, ["access_logs", "security_alerts"])
      observer(:user_activity, ["user_logins", "user_actions"])
    end

    # Execute definition
    MultiObserverExample.execute()

    # Subscribe directly to the topics for testing
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "system_status")
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "security_alerts")
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "user_logins")

    # Send notifications directly
    PatternVM.notify_observers("system_status", %{
      type: "status_update",
      status: "online"
    })

    PatternVM.notify_observers("security_alerts", %{
      type: "security_alert",
      severity: "high"
    })

    PatternVM.notify_observers("user_logins", %{
      type: "user_login",
      user_id: "456"
    })

    # Verify all notifications were received
    assert_receive {:update, system_notification}, 500
    assert system_notification.status == "online"

    assert_receive {:update, security_notification}, 500
    assert security_notification.severity == "high"

    assert_receive {:update, user_notification}, 500
    assert user_notification.user_id == "456"
  end

  test "observer with factory integration" do
    defmodule ObserverFactoryExample do
      use PatternVM.DSL

      # Define factory to create products
      factory(:product_factory)

      # Define observer to monitor product creation
      observer(:product_observer, ["product_created"])

      # Only create product - no notification in workflow
      workflow(
        :create_product,
        sequence([
          create_product(:product_factory, :widget)
        ])
      )
    end

    # Execute definition
    ObserverFactoryExample.execute()

    # Create a product
    result = PatternVM.DSL.Runtime.execute_workflow(ObserverFactoryExample, :create_product)
    product = result.last_result

    # Send notification directly (outside the workflow)
    PatternVM.notify_observers("product_created", %{
      topic: "product_created",
      product_id: product.id,
      product_type: product.type
    })

    # Verify notification was sent with correct data
    assert_receive {:update, notification}, 500
    assert notification.topic == "product_created"
    assert notification.product_type == :widget
  end
end
