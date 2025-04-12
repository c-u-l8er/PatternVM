defmodule PatternVM.PubSubTest do
  use ExUnit.Case

  setup do
    # Start Phoenix.PubSub for testing if not already started
    case Phoenix.PubSub.Supervisor.start_link(name: PatternVM.PubSub) do
      {:ok, pid} ->
        on_exit(fn ->
          try do
            Process.exit(pid, :normal)
          catch
            _kind, _reason -> :ok
          end
        end)

      {:error, {:already_started, _pid}} ->
        :ok
    end

    :ok
  end

  test "can subscribe to a topic" do
    topic = "test-topic-#{System.unique_integer([:positive])}"

    # Subscribe to the test topic
    :ok = PatternVM.PubSub.subscribe(topic)

    # Broadcast a message
    :ok = PatternVM.PubSub.broadcast(topic, {:test, "Hello"})

    # Assert the message is received
    assert_receive {:test, "Hello"}
  end

  test "only subscribers receive messages" do
    topic1 = "test-topic-1-#{System.unique_integer([:positive])}"
    topic2 = "test-topic-2-#{System.unique_integer([:positive])}"

    # Subscribe only to topic1
    :ok = PatternVM.PubSub.subscribe(topic1)

    # Broadcast to both topics
    :ok = PatternVM.PubSub.broadcast(topic1, {:test, "Topic 1"})
    :ok = PatternVM.PubSub.broadcast(topic2, {:test, "Topic 2"})

    # Should receive message from topic1
    assert_receive {:test, "Topic 1"}

    # Should not receive message from topic2
    refute_received {:test, "Topic 2"}
  end

  test "multiple subscribers receive the same message" do
    topic = "test-topic-#{System.unique_integer([:positive])}"
    test_pid = self()

    # Create another process that forwards messages to this test process
    subscriber_pid =
      spawn(fn ->
        :ok = PatternVM.PubSub.subscribe(topic)
        send(test_pid, :subscribed)

        receive do
          msg -> send(test_pid, {:forwarded, msg})
        end
      end)

    # Wait for the other process to subscribe
    assert_receive :subscribed

    # Subscribe in this process too
    :ok = PatternVM.PubSub.subscribe(topic)

    # Broadcast a message
    :ok = PatternVM.PubSub.broadcast(topic, {:test, "Broadcast"})

    # Both processes should receive the message
    assert_receive {:test, "Broadcast"}
    assert_receive {:forwarded, {:test, "Broadcast"}}
  end
end
