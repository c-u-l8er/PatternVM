defmodule PatternVM.BuilderTest do
  use ExUnit.Case

  setup do
    {:ok, state} = PatternVM.Builder.initialize(%{})
    %{state: state}
  end

  test "builds a complex product step by step", %{state: state} do
    params = %{
      name: "Test Product",
      parts: ["part1", "part2", "part3"],
      metadata: %{version: "1.0", color: "blue"}
    }

    {:ok, product, ^state} =
      PatternVM.Builder.handle_interaction(:build_step_by_step, params, state)

    assert product.name == "Test Product"
    # Note: parts are prepended
    assert product.parts == ["part3", "part2", "part1"]
    assert product.metadata.version == "1.0"
    assert product.metadata.color == "blue"
  end

  test "builds a product with no parts", %{state: state} do
    params = %{
      name: "Empty Product",
      parts: [],
      metadata: %{type: "sample"}
    }

    {:ok, product, ^state} =
      PatternVM.Builder.handle_interaction(:build_step_by_step, params, state)

    assert product.name == "Empty Product"
    assert product.parts == []
    assert product.metadata.type == "sample"
  end

  test "builds a product with only required fields", %{state: state} do
    params = %{
      name: "Minimal Product",
      parts: [],
      metadata: %{}
    }

    {:ok, product, ^state} =
      PatternVM.Builder.handle_interaction(:build_step_by_step, params, state)

    assert product.name == "Minimal Product"
    assert product.parts == []
    assert product.metadata == %{}
  end
end
