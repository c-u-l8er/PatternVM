defmodule PatternVM.ObserverTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    # Test with no topics
    {:ok, state} = PatternVM.Observer.initialize(%{})
    assert state == %{topics: [], callbacks: %{}}

    # Test with topics
    {:ok, state_with_topics} = PatternVM.Observer.initialize(%{topics: ["topic1", "topic2"]})
    assert state_with_topics == %{topics: ["topic1", "topic2"], callbacks: %{}}
  end

  test "subscribe adds a topic and callback" do
    # Initialize observer
    {:ok, state} = PatternVM.Observer.initialize(%{})
    callback = fn _ -> :callback_called end

    # Subscribe to a topic
    {:ok, result, new_state} =
      PatternVM.Observer.handle_interaction(
        :subscribe,
        %{topic: "new_topic", callback: callback},
        state
      )

    # Verify subscription was added
    assert result == {:subscribed, "new_topic"}
    assert "new_topic" in new_state.topics
    assert Map.has_key?(new_state.callbacks, "new_topic")
    assert is_function(new_state.callbacks["new_topic"])
  end

  test "observer pattern_name returns the expected atom" do
    assert PatternVM.Observer.pattern_name() == :observer
  end
end
