defmodule PatternVM.Integration.PatternInteractionsTest do
  use ExUnit.Case

  setup do
    # Start PatternVM for integration tests
    {:ok, pid} = PatternVM.start_link([])

    # Mock logger to prevent warnings
    if !Process.whereis(PatternVM.Logger) do
      defmodule PatternVM.Logger do
        def log_interaction(_, _, _), do: :ok
      end
    end

    # Mock Supervisor
    if !Process.whereis(PatternVM.Supervisor) do
      defmodule PatternVM.Supervisor do
        def start_child(_, _), do: {:ok, spawn(fn -> :ok end)}
      end
    end

    # Mock PubSub for testing
    if !Process.whereis(Phoenix.PubSub) do
      defmodule Phoenix.PubSub do
        def subscribe(_, _), do: :ok
        def broadcast(_, _, _), do: :ok
      end
    end

    # Mock UUID for testing
    if !Process.whereis(UUID) do
      defmodule UUID do
        def uuid4(), do: "test-uuid"
      end
    end

    %{pattern_vm_pid: pid}
  end

  test "builder pattern interacting with strategy pattern", %{pattern_vm_pid: _pid} do
    # Register a builder pattern
    {:ok, builder_name} = PatternVM.register_pattern(PatternVM.Builder, %{name: :test_builder})

    # Register a strategy pattern
    {:ok, strategy_name} = PatternVM.register_pattern(PatternVM.Strategy, %{name: :test_strategy})

    # Add a strategy
    pricing_strategy = fn product ->
      base_price = 100
      parts_price = length(product.parts) * 50
      Map.put(product, :price, base_price + parts_price)
    end

    PatternVM.interact(strategy_name, :register_strategy, %{
      name: :pricing,
      function: pricing_strategy
    })

    # Build a product with the builder
    product_params = %{
      name: "Test Product",
      parts: ["frame", "engine", "wheels"],
      metadata: %{quality: "premium"}
    }

    built_product = PatternVM.interact(builder_name, :build_step_by_step, product_params)

    # Apply strategy to calculate price
    priced_product =
      PatternVM.interact(strategy_name, :execute_strategy, %{
        name: :pricing,
        args: built_product
      })

    # Verify interaction result
    assert priced_product.name == "Test Product"
    assert length(priced_product.parts) == 3
    # 100 base + (3 parts * 50)
    assert priced_product.price == 250
  end

  test "factory pattern with observer notification" do
    # Register patterns
    {:ok, factory_name} = PatternVM.register_pattern(PatternVM.Factory, %{name: :test_factory})

    {:ok, observer_name} =
      PatternVM.register_pattern(PatternVM.Observer, %{
        name: :test_observer,
        topics: ["products"]
      })

    # Mock broadcast to capture notification
    original_broadcast = &Phoenix.PubSub.broadcast/3
    notification_received = nil

    try do
      :meck.new(Phoenix.PubSub, [:passthrough])

      :meck.expect(Phoenix.PubSub, :broadcast, fn pubsub, topic, message ->
        notification_received = {pubsub, topic, message}
        original_broadcast.(pubsub, topic, message)
      end)

      # Create a product
      product = PatternVM.interact(factory_name, :create_product, %{type: :widget})

      # Notify about the product
      PatternVM.notify_observers("products", product)

      # Verify notification was sent
      assert :meck.called(Phoenix.PubSub, :broadcast, [:_, "products", :_])
    after
      if :meck.validate(Phoenix.PubSub) do
        :meck.unload(Phoenix.PubSub)
      end
    end
  end

  test "chain of responsibility with command pattern" do
    # Register patterns
    {:ok, chain_name} =
      PatternVM.register_pattern(PatternVM.ChainOfResponsibility, %{
        name: :error_handler
      })

    {:ok, command_name} =
      PatternVM.register_pattern(PatternVM.Command, %{
        name: :error_commands
      })

    # Define handlers for different error types
    validation_handler = fn request ->
      %{success: false, error: "Validation error: #{request.message}"}
    end

    db_handler = fn request ->
      %{success: false, error: "Database error: #{request.message}"}
    end

    # Register handlers with the chain
    PatternVM.interact(chain_name, :register_handler, %{
      name: :validation_handler,
      can_handle_fn: fn req -> req.type == :validation end,
      handle_fn: validation_handler,
      priority: 10
    })

    PatternVM.interact(chain_name, :register_handler, %{
      name: :db_handler,
      can_handle_fn: fn req -> req.type == :database end,
      handle_fn: db_handler,
      priority: 5
    })

    # Register commands
    PatternVM.interact(command_name, :register_command, %{
      name: :log_error,
      execute_fn: fn error -> %{logged: true, error: error} end,
      undo_fn: fn _ -> %{logged: false} end
    })

    # Process an error through the chain
    validation_error = %{type: :validation, message: "Invalid input"}
    error_result = PatternVM.interact(chain_name, :process_request, %{request: validation_error})

    # Log the error with the command pattern
    command_result =
      PatternVM.interact(command_name, :execute, %{
        command: :log_error,
        args: error_result
      })

    # Verify results
    assert error_result.success == false
    assert String.starts_with?(error_result.error, "Validation error")
    assert command_result.logged == true
    assert command_result.error == error_result
  end
end
