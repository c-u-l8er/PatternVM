defmodule PatternVM.DSL.CombinedPatternsTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "basic combined pattern workflow" do
    # Register patterns directly with PatternVM
    PatternVM.register_pattern(PatternVM.Factory, %{name: :test_factory})
    PatternVM.register_pattern(PatternVM.Singleton, %{name: :test_config, instance: "Config Value"})

    # Use PatternVM directly
    product = PatternVM.interact(:test_factory, :create_product, %{type: :widget})
    config = PatternVM.interact(:test_config, :get_instance)

    assert product.type == :widget
    assert config == "Config Value"
  end

  test "using multiple patterns with custom workflow" do
    # Set up the patterns we need directly
    PatternVM.register_pattern(PatternVM.Factory, %{name: :direct_factory})
    PatternVM.register_pattern(PatternVM.Decorator, %{
      name: :direct_decorator,
      decorators: %{
        premium: fn product -> Map.put(product, :quality, "premium") end,
        discount: fn product -> Map.put(product, :price, 90) end
      }
    })

    # Execute a simple workflow sequence manually
    product = PatternVM.interact(:direct_factory, :create_product, %{type: :gadget})
    premium_product = PatternVM.interact(:direct_decorator, :decorate, %{
      object: product,
      decorators: [:premium]
    })

    final_product = PatternVM.interact(:direct_decorator, :decorate, %{
      object: premium_product,
      decorators: [:discount]
    })

    # Verify the result
    assert product.type == :gadget
    assert premium_product.quality == "premium"
    assert final_product.price == 90
  end
end
