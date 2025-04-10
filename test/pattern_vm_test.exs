defmodule PatternVMTest do
  use ExUnit.Case
  doctest PatternVM

  setup do
    # Clear test logs before each test
    PatternVM.Logger.clear_test_logs()
    :ok
  end

  test "basic pattern registration" do
    # Test registering a pattern
    {:ok, pattern_name} =
      PatternVM.register_pattern(PatternVM.Singleton, %{name: :test_singleton})

    assert pattern_name == :test_singleton

    # Verify we can interact with the registered pattern
    result = PatternVM.interact(:test_singleton, :get_instance)
    assert result == "I am the Singleton"
  end

  test "pattern interaction" do
    # Register a factory pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Factory, %{name: :test_factory})

    # Create a product
    product = PatternVM.interact(:test_factory, :create_product, %{type: :widget})

    # Verify product structure
    assert Map.has_key?(product, :type)
    assert Map.has_key?(product, :id)
    assert Map.has_key?(product, :created_at)
    assert product.type == :widget
  end

  test "notify observers" do
    # Register an observer
    {:ok, _} =
      PatternVM.register_pattern(PatternVM.Observer, %{
        name: :test_observer,
        topics: ["test_topic"]
      })

    # Simulate a notification
    data = %{message: "test message"}
    result = PatternVM.notify_observers("test_topic", data)

    # Verify the data was passed through
    assert result == data

    # Check logs to verify notification was processed
    logs = PatternVM.Logger.get_test_logs()

    assert Enum.any?(logs, fn {source, action, _} ->
             source == "Observer" && action == "received_update"
           end)
  end
end
