defmodule PatternVM.E2ETest do
  use ExUnit.Case

  # Create missing modules
  unless Code.ensure_loaded?(PatternVM.Logger) do
    defmodule PatternVM.Logger do
      def log_interaction(_source, _action, _data), do: :ok
    end
  end

  unless Code.ensure_loaded?(PatternVM.PubSub) do
    defmodule PatternVM.PubSub do
      def subscribe(_topic), do: :ok
      def broadcast(_topic, _message), do: :ok
    end
  end

  unless Code.ensure_loaded?(PatternVM.Supervisor) do
    defmodule PatternVM.Supervisor do
      def start_child(_module, _args) do
        {:ok, spawn(fn -> :ok end)}
      end
    end
  end

  setup do
    # Make sure we have the ETS table for tracking children
    if Application.get_env(:pattern_vm, :testing, false) do
      # Create table if it doesn't exist
      try do
        :ets.info(:pattern_vm_children)
      rescue
        _ -> :ets.new(:pattern_vm_children, [:named_table, :public])
      catch
        :error, :badarg -> :ets.new(:pattern_vm_children, [:named_table, :public])
      end
    end

    # Start a fresh PatternVM instance for each test
    {:ok, pid} = PatternVM.start_link([])

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :normal)
    end)

    %{pattern_vm_pid: pid}
  end

  test "can register and use patterns" do
    # Register patterns
    {:ok, _} =
      PatternVM.register_pattern(PatternVM.Singleton, %{
        name: :test_config,
        instance: "Test Config Value"
      })

    {:ok, _} = PatternVM.register_pattern(PatternVM.Factory, %{name: :test_factory})

    # Interact with singleton pattern
    singleton_value = PatternVM.interact(:test_config, :get_instance)
    assert singleton_value == "Test Config Value"

    # Create a product using factory pattern - check type only as ID might vary
    product = PatternVM.interact(:test_factory, :create_product, %{type: :widget})
    assert product.type == :widget
  end

  test "can use builder pattern for complex objects" do
    # Register builder pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Builder, %{name: :product_builder})

    # Build a complex product
    product =
      PatternVM.interact(:product_builder, :build_step_by_step, %{
        name: "Complex Widget",
        parts: ["part1", "part2", "part3"],
        metadata: %{version: "1.0", quality: "premium"}
      })

    assert product.name == "Complex Widget"
    assert length(product.parts) == 3
    assert product.metadata.version == "1.0"
    assert product.metadata.quality == "premium"
  end

  test "can register and execute strategies" do
    # Register strategy pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Strategy, %{name: :pricing_strategy})

    # Register a strategy
    discount_fn = fn product ->
      base_price = Map.get(product, :price, 100)
      Map.put(product, :price, base_price * 0.8)
    end

    result =
      PatternVM.interact(:pricing_strategy, :register_strategy, %{
        name: :discount,
        function: discount_fn
      })

    assert match?({:registered, :discount}, result)

    # Execute the strategy
    test_product = %{name: "Test Widget", price: 100}

    discounted =
      PatternVM.interact(:pricing_strategy, :execute_strategy, %{
        name: :discount,
        args: test_product
      })

    assert discounted.price == 80.0
  end

  test "can use adapter pattern" do
    # Register adapter pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Adapter, %{name: :format_adapter})

    # Register an adapter
    json_fn = fn map ->
      "{" <> Enum.map_join(map, ",", fn {k, v} -> "\"#{k}\":\"#{v}\"" end) <> "}"
    end

    PatternVM.interact(:format_adapter, :register_adapter, %{
      for_type: :map_to_json,
      adapter_fn: json_fn
    })

    # Use the adapter
    result =
      PatternVM.interact(:format_adapter, :adapt, %{
        object: %{name: "Widget", id: "123"},
        to_type: :map_to_json
      })

    assert result == "{\"id\":\"123\",\"name\":\"Widget\"}"
  end

  test "can use decorator pattern" do
    # Register decorator pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Decorator, %{name: :widget_decorator})

    # Register decorators
    premium_fn = fn widget -> Map.put(widget, :quality, "premium") end

    discount_fn = fn widget ->
      price = Map.get(widget, :price, 100)
      Map.put(widget, :price, price * 0.8)
    end

    PatternVM.interact(:widget_decorator, :register_decorator, %{
      name: :premium,
      decorator_fn: premium_fn
    })

    PatternVM.interact(:widget_decorator, :register_decorator, %{
      name: :discount,
      decorator_fn: discount_fn
    })

    # Use decorator
    widget = %{name: "Basic Widget", price: 100}

    decorated =
      PatternVM.interact(:widget_decorator, :decorate, %{
        object: widget,
        decorators: [:premium, :discount]
      })

    assert decorated.quality == "premium"
    assert decorated.price == 80.0
  end

  test "composite pattern creates valid component structure" do
    # Register composite pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Composite, %{name: :catalog})

    # Create components
    category =
      PatternVM.interact(:catalog, :create_component, %{
        id: "cat1",
        name: "Category 1",
        type: :category,
        data: %{description: "Main category"}
      })

    assert category.id == "cat1"
    assert category.type == :category

    PatternVM.interact(:catalog, :create_component, %{
      id: "prod1",
      name: "Product 1",
      type: :product,
      data: %{price: 100}
    })

    PatternVM.interact(:catalog, :create_component, %{
      id: "prod2",
      name: "Product 2",
      type: :product,
      data: %{price: 200}
    })

    # Add children
    result =
      PatternVM.interact(:catalog, :add_child, %{
        parent_id: "cat1",
        child_id: "prod1"
      })

    assert result.children |> Enum.any?(fn child -> child.id == "prod1" end)
  end

  test "proxy pattern controls access to services" do
    # Register proxy pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Proxy, %{name: :api_proxy})

    # Register services
    get_widget = fn id -> %{id: id, name: "Widget #{id}"} end
    delete_widget = fn id -> %{id: id, deleted: true} end

    PatternVM.interact(:api_proxy, :register_service, %{
      name: :get_widget,
      handler: get_widget
    })

    PatternVM.interact(:api_proxy, :register_service, %{
      name: :delete_widget,
      handler: delete_widget
    })

    # Set access rule for delete
    admin_only = fn context, _args -> context[:role] == "admin" end

    PatternVM.interact(:api_proxy, :set_access_rule, %{
      service: :delete_widget,
      rule: admin_only
    })

    # Test access
    # Everyone can get
    result1 =
      PatternVM.interact(:api_proxy, :request, %{
        service: :get_widget,
        args: "123",
        context: %{role: "user"}
      })

    assert result1.id == "123"

    # Only admin can delete
    result2 =
      PatternVM.interact(:api_proxy, :request, %{
        service: :delete_widget,
        args: "123",
        context: %{role: "user"}
      })

    assert match?({:error, _}, result2)

    # Admin can delete
    result3 =
      PatternVM.interact(:api_proxy, :request, %{
        service: :delete_widget,
        args: "123",
        context: %{role: "admin"}
      })

    assert result3.deleted == true
  end

  test "chain of responsibility pattern handles requests properly" do
    # Register chain of responsibility pattern
    {:ok, _} =
      PatternVM.register_pattern(PatternVM.ChainOfResponsibility, %{name: :error_handler})

    # Register handlers
    PatternVM.interact(:error_handler, :register_handler, %{
      name: :validation_handler,
      can_handle_fn: fn req -> req.type == :validation end,
      handle_fn: fn req -> "Validation error: #{req.message}" end,
      priority: 10
    })

    PatternVM.interact(:error_handler, :register_handler, %{
      name: :database_handler,
      can_handle_fn: fn req -> req.type == :database end,
      handle_fn: fn req -> "Database error: #{req.message}" end,
      priority: 5
    })

    # Process requests
    result1 =
      PatternVM.interact(:error_handler, :process_request, %{
        request: %{type: :validation, message: "Invalid input"}
      })

    assert result1 == "Validation error: Invalid input"

    result2 =
      PatternVM.interact(:error_handler, :process_request, %{
        request: %{type: :database, message: "Connection failed"}
      })

    assert result2 == "Database error: Connection failed"
  end

  test "command pattern executes and undoes commands" do
    # Register command pattern
    {:ok, _} = PatternVM.register_pattern(PatternVM.Command, %{name: :widget_commands})

    # Register command
    create_widget = fn args -> %{id: "widget-#{args[:id] || "123"}", created: true} end
    delete_widget = fn args -> %{id: "widget-#{args[:id] || "123"}", deleted: true} end

    PatternVM.interact(:widget_commands, :register_command, %{
      name: :create_widget,
      execute_fn: create_widget,
      undo_fn: delete_widget
    })

    # Execute command
    result1 =
      PatternVM.interact(:widget_commands, :execute, %{
        command: :create_widget,
        args: %{id: "456"}
      })

    assert result1.id == "widget-456"
    assert result1.created == true

    # Undo command
    result2 = PatternVM.interact(:widget_commands, :undo, %{})

    assert result2.id == "widget-456"
    assert result2.deleted == true
  end
end
