defmodule PatternVM.DSL.BuilderTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "builder pattern definition and product construction" do
    defmodule BuilderExample do
      use PatternVM.DSL

      # Define builder pattern
      pattern(:product_builder, :builder)

      # Define workflow for building a simple product
      workflow(
        :build_simple_product,
        sequence([
          build_product(:product_builder, "Simple Widget", ["frame", "button", "display"], %{
            color: "blue",
            size: "medium"
          })
        ])
      )

      # Define workflow for building a complex product
      workflow(
        :build_complex_product,
        sequence([
          build_product(
            :product_builder,
            "Complex Gadget",
            ["frame", "power_unit", "display", "wifi_module", "battery", "speakers"],
            %{
              color: "black",
              size: "large",
              version: "2.0",
              premium: true
            }
          )
        ])
      )
    end

    # Execute definition
    BuilderExample.execute()

    # Test building a simple product
    result1 = PatternVM.DSL.Runtime.execute_workflow(BuilderExample, :build_simple_product)
    assert result1.last_result.name == "Simple Widget"
    assert length(result1.last_result.parts) == 3
    assert "frame" in result1.last_result.parts
    assert result1.last_result.metadata.color == "blue"

    # Test building a complex product
    result2 = PatternVM.DSL.Runtime.execute_workflow(BuilderExample, :build_complex_product)
    assert result2.last_result.name == "Complex Gadget"
    assert length(result2.last_result.parts) == 6
    assert result2.last_result.metadata.premium == true
  end

  test "builder with available parts configuration" do
    defmodule ConfiguredBuilder do
      use PatternVM.DSL

      # Define builder with available parts configuration
      builder(:furniture_builder, ["leg", "seat", "back", "arm"])

      # Workflow to build a chair using the available parts
      workflow(
        :build_chair,
        sequence([
          build_product(
            :furniture_builder,
            "Basic Chair",
            ["leg", "leg", "leg", "leg", "seat", "back"],
            %{
              style: "modern",
              material: "wood"
            }
          )
        ])
      )
    end

    # Execute definition
    ConfiguredBuilder.execute()

    # Test building a chair
    result = PatternVM.DSL.Runtime.execute_workflow(ConfiguredBuilder, :build_chair)
    assert result.last_result.name == "Basic Chair"

    # Should have 6 parts (4 legs + seat + back)
    assert length(result.last_result.parts) == 6

    # Verify metadata
    assert result.last_result.metadata.style == "modern"
    assert result.last_result.metadata.material == "wood"
  end
end
