defmodule PatternVM.ObserverTest do
  use ExUnit.Case

  # Make sure the test PubSub is defined
  defmodule TestPubSub do
    def subscribe(_), do: :ok
  end

  setup do
    # Override PubSub module for testing
    original_pubsub = :persistent_term.get({__MODULE__, :pubsub}, nil)
    :persistent_term.put({__MODULE__, :pubsub}, TestPubSub)

    on_exit(fn ->
      if original_pubsub do
        :persistent_term.put({__MODULE__, :pubsub}, original_pubsub)
      else
        :persistent_term.erase({__MODULE__, :pubsub})
      end
    end)

    {:ok, state} = PatternVM.Observer.initialize(%{topics: ["test-topic"]})
    %{state: state}
  end

  test "subscribes to topic", %{state: state} do
    callback = fn data -> send(self(), {:callback_called, data}) end

    {:ok, {:subscribed, "new-topic"}, new_state} =
      PatternVM.Observer.handle_interaction(
        :subscribe,
        %{
          topic: "new-topic",
          callback: callback
        },
        state
      )

    assert "new-topic" in new_state.topics
    assert Map.has_key?(new_state.callbacks, "new-topic")
    assert new_state.callbacks["new-topic"] == callback
  end

  test "initializes with provided topics", %{state: state} do
    assert state.topics == ["test-topic"]
  end

  test "handles messages", %{state: state} do
    # Setup a test process to receive messages
    test_pid = self()
    callback = fn data -> send(test_pid, {:callback_executed, data}) end

    # Add callback
    state_with_callback = %{state | callbacks: %{"test-topic" => callback}}

    # Simulate receiving a message
    message = {:update, %{topic: "test-topic", value: 42}}

    {:noreply, ^state_with_callback} =
      PatternVM.Observer.handle_info(message, state_with_callback)

    # Check if callback was executed
    assert_receive {:callback_executed, %{topic: "test-topic", value: 42}}
  end

  test "ignores messages for unsubscribed topics", %{state: state} do
    # Setup a test process to receive messages
    test_pid = self()
    callback = fn _ -> send(test_pid, :should_not_be_called) end

    # Add callback for a different topic
    state_with_callback = %{state | callbacks: %{"other-topic" => callback}}

    # Simulate receiving a message for test-topic
    message = {:update, %{topic: "test-topic", value: 42}}

    {:noreply, ^state_with_callback} =
      PatternVM.Observer.handle_info(message, state_with_callback)

    # Make sure callback wasn't called
    refute_receive :should_not_be_called
  end
end
