defmodule PatternVM.DSL.NotifyTest do
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

    # Store test pid in process dictionary for callbacks
    Process.put(:test_pid, self())

    # Subscribe to test topics directly
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "test_notifications")
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "context_notifications")
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "complex_notifications")

    :ok
  end

  test "direct notification without DSL" do
    # Send notification directly
    PatternVM.notify_observers("test_notifications", %{
      type: "direct_test",
      message: "This is a direct notification",
      timestamp: "placeholder-time" # Don't use DateTime here
    })

    # Verify notification was received
    assert_receive {:update, notification}, 500
    assert notification.type == "direct_test"
    assert notification.message == "This is a direct notification"
    assert notification.topic == "test_notifications"
  end

  test "notification via PatternVM execute_workflow_steps" do
    # Define a workflow step that sends a notification
    workflow_step = {:notify, "context_notifications", %{
      user_id: "user-123",
      action: "login",
      timestamp: "placeholder-time" # Don't use DateTime here
    }}

    # Execute the workflow step directly using the runtime
    PatternVM.DSL.Runtime.execute_workflow_steps(workflow_step, %{})

    # Verify notification was received
    assert_receive {:update, notification}, 500
    assert notification.user_id == "user-123"
    assert notification.action == "login"
    assert notification.topic == "context_notifications"
  end

  test "notification with context variables via runtime" do
    # Define context
    context = %{
      user_id: "user-abc",
      event: %{id: "event-123", type: "login"},
      timestamp: "placeholder-time" # Don't use DateTime here
    }

    # Define workflow step with context references
    workflow_step = {:notify, "context_notifications", %{
      user_id: {:context, :user_id},
      event_id: {:context, :event, :id},
      event_type: {:context, :event, :type}
    }}

    # Execute the workflow step directly
    PatternVM.DSL.Runtime.execute_workflow_steps(workflow_step, context)

    # Verify notification was received with context values
    assert_receive {:update, notification}, 500
    assert notification.user_id == "user-abc"
    assert notification.event_id == "event-123"
    assert notification.event_type == "login"
    assert notification.topic == "context_notifications"
  end

  test "complex notification with nested data via sequence" do
    # Create complex context
    context = %{
      state: %{
        system: %{
          version: "2.0",
          features: ["feature1", "feature2", "feature3"]
        },
        settings: %{
          theme: "light"
        }
      }
    }

    # Define workflow with transform and context references
    workflow = {:sequence, [
      # Use explicit transformation instead of relying on list indexing
      {:transform, :first_feature,
        fn ctx ->
          List.first(ctx.state.system.features)
        end
      },
      # Send notification with nested references
      {:notify, "complex_notifications", %{
        version: {:context, :state, :system, :version},
        theme: {:context, :state, :settings, :theme},
        first_feature: {:context, :first_feature}
      }}
    ]}

    # Execute the workflow
    PatternVM.DSL.Runtime.execute_workflow_steps(workflow, context)

    # Verify complex notification
    assert_receive {:update, notification}, 500
    assert notification.version == "2.0"
    assert notification.theme == "light"
    assert notification.first_feature == "feature1"
    assert notification.topic == "complex_notifications"
  end
end
