defmodule PatternVMTest do
  use ExUnit.Case
  doctest PatternVM

  setup do
    # Start PatternVM for each test
    {:ok, pid} = PatternVM.start_link([])
    # Create a Logger module mock to prevent warnings
    if !Process.whereis(PatternVM.Logger) do
      defmodule PatternVM.Logger do
        def log_interaction(_, _, _), do: :ok
      end
    end

    # Create a Supervisor module mock if needed
    if !Process.whereis(PatternVM.Supervisor) do
      defmodule PatternVM.Supervisor do
        def start_child(_, _), do: {:ok, spawn(fn -> :ok end)}
      end
    end

    %{pattern_vm_pid: pid}
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
    # Set up a test PubSub module if needed
    if !Process.whereis(PatternVM.PubSub) do
      defmodule PatternVM.PubSub do
        def subscribe(_), do: :ok
      end
    end

    if !Process.whereis(Phoenix.PubSub) do
      defmodule Phoenix.PubSub do
        def subscribe(_, _), do: :ok
        def broadcast(_, _, _), do: :ok
      end
    end

    # Register an observer
    {:ok, _} =
      PatternVM.register_pattern(PatternVM.Observer, %{
        name: :test_observer,
        topics: ["test_topic"]
      })

    # Simulate a notification (we're just testing the interface works)
    data = %{message: "test message"}
    result = PatternVM.notify_observers("test_topic", data)

    # Verify the data was passed through
    assert result == data
  end
end
