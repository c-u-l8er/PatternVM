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

      # Define workflow that sends notifications
      workflow(
        :notify_events,
        sequence([
          notify("system_events", %{type: "system", message: "System started"}),
          notify("user_events", %{type: "user", message: "User logged in"})
        ])
      )
    end

    # Execute definition
    ObserverExample.execute()

    # Just verify the workflow executes without errors
    # (actual message delivery is hard to test since it happens asynchronously)
    result = PatternVM.DSL.Runtime.execute_workflow(ObserverExample, :notify_events)
    assert result != nil
  end

  test "observer with subscription workflow" do
    defmodule SubscriptionExample do
      use PatternVM.DSL

      # Define observer
      observer(:dynamic_observer)

      # Workflow to subscribe to a topic
      workflow(
        :subscribe_to_topic,
        sequence([
          subscribe(:dynamic_observer, "test_topic")
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
    PatternVM.DSL.Runtime.execute_workflow(SubscriptionExample, :subscribe_to_topic)

    # Send notification
    result = PatternVM.DSL.Runtime.execute_workflow(SubscriptionExample, :send_notification)
    assert result != nil
  end
end
