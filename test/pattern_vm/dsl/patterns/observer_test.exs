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

    :ok
  end

  test "observer pattern definition" do
    defmodule ObserverExample do
      use PatternVM.DSL

      # Define observer patterns
      observer(:system_observer, ["system_events"])
      observer(:user_observer, ["user_events", "login_events"])

      # Define callback function
      def log_event(_data) do
        # Just a placeholder function for testing
        :event_logged
      end

      # Define workflow that sends notifications
      workflow(
        :notify_events,
        sequence([
          notify("system_events", %{type: "system", message: "System started"}),
          notify("user_events", %{type: "user", message: "User logged in"})
        ])
      )

      # Workflow to subscribe with callback
      workflow(
        :subscribe_with_callback,
        sequence([
          {:interact, :system_observer, :subscribe,
           %{
             topic: "error_events",
             callback: {__MODULE__, :log_event, 1}
           }}
        ])
      )
    end

    # Execute definition
    ObserverExample.execute()

    # Just verify the workflow executes without errors
    # (actual message delivery is hard to test since it happens asynchronously)
    result = PatternVM.DSL.Runtime.execute_workflow(ObserverExample, :notify_events)
    assert result != nil

    # Also check subscription
    subscription_result = PatternVM.DSL.Runtime.execute_workflow(ObserverExample, :subscribe_with_callback)
    assert match?({:subscribed, "error_events"}, subscription_result.last_result)
  end

  test "observer with subscription workflow" do
    defmodule SubscriptionExample do
      use PatternVM.DSL

      # Define observer
      observer(:dynamic_observer)

      # Callback function
      def test_callback(_data) do
        # Just a placeholder for testing
        :callback_executed
      end

      # Workflow to subscribe to a topic with MFA tuple
      workflow(
        :subscribe_to_topic,
        sequence([
          {:interact, :dynamic_observer, :subscribe,
           %{
             topic: "test_topic",
             callback: {__MODULE__, :test_callback, 1}
           }}
        ])
      )

      # Workflow to send notification
      workflow(
        :send_notification,
        sequence([
          notify("test_topic", %{message: "Test notification"})
        ])
      )
    end

    # Execute definition
    SubscriptionExample.execute()

    # Subscribe to topic
    result1 = PatternVM.DSL.Runtime.execute_workflow(SubscriptionExample, :subscribe_to_topic)
    assert match?({:subscribed, "test_topic"}, result1.last_result)

    # Send notification
    result2 = PatternVM.DSL.Runtime.execute_workflow(SubscriptionExample, :send_notification)
    assert result2 != nil
  end
end
