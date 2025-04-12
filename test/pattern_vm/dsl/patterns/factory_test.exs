defmodule PatternVM.DSL.FactoryTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "factory pattern definition and product creation" do
    defmodule FactoryExample do
      use PatternVM.DSL

      # Define factory pattern
      factory(:product_factory)

      # Define workflow for creating widget
      workflow(
        :create_widget,
        sequence([
          create_product(:product_factory, :widget)
        ])
      )

      # Define workflow for creating different product types
      workflow(
        :create_multiple,
        sequence([
          create_product(:product_factory, :widget),
          {:store, :widget, :last_result},
          create_product(:product_factory, :gadget),
          {:store, :gadget, :last_result},
          create_product(:product_factory, :tool),
          {:store, :tool, :last_result}
        ])
      )
    end

    # Execute definition
    FactoryExample.execute()

    # Test create_widget workflow
    result1 = PatternVM.DSL.Runtime.execute_workflow(FactoryExample, :create_widget)
    assert result1.last_result.type == :widget

    # Test create_multiple workflow
    result2 = PatternVM.DSL.Runtime.execute_workflow(FactoryExample, :create_multiple)

    # Verify all products were created with correct types
    assert result2.widget.type == :widget
    assert result2.gadget.type == :gadget
    assert result2.tool.type == :tool

    # Products should have unique IDs
    assert result2.widget.id != result2.gadget.id
    assert result2.gadget.id != result2.tool.id
  end

  test "factory with products configuration" do
    defmodule ConfiguredFactory do
      use PatternVM.DSL

      # Define factory with products configuration
      factory(:configured_factory, [:custom_widget, :premium_gadget])

      # Workflow to create the configured products
      workflow(
        :create_custom_product,
        sequence([
          create_product(:configured_factory, :custom_widget)
        ])
      )
    end

    # Execute definition
    ConfiguredFactory.execute()

    # Test creating a custom product
    # Note: Factory doesn't actually use the products config yet,
    # but the test verifies the DSL accepts the configuration
    result = PatternVM.DSL.Runtime.execute_workflow(ConfiguredFactory, :create_custom_product)
    assert result.last_result.type == :custom_widget
  end

  test "factory pattern with parallel product creation" do
    defmodule ParallelFactory do
      use PatternVM.DSL

      factory(:mass_factory)

      # Workflow using parallel to create multiple products at once
      workflow(
        :parallel_production,
        parallel([
          create_product(:mass_factory, :widget),
          create_product(:mass_factory, :gadget),
          create_product(:mass_factory, :tool)
        ])
      )
    end

    # Execute definition
    ParallelFactory.execute()

    # Run parallel workflow
    result = PatternVM.DSL.Runtime.execute_workflow(ParallelFactory, :parallel_production)

    # Should have 3 products in parallel_results
    assert length(result.parallel_results) == 3

    # Verify all product types were created
    types = Enum.map(result.parallel_results, fn p -> p.type end)
    assert :widget in types
    assert :gadget in types
    assert :tool in types
  end
end
