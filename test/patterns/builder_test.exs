defmodule PatternVM.BuilderTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Builder.initialize(%{})
    assert state == %{}
  end

  test "build_step_by_step creates a complex product" do
    # Initialize the builder
    {:ok, state} = PatternVM.Builder.initialize(%{})

    # Build parameters
    params = %{
      name: "Test Product",
      parts: ["part1", "part2", "part3"],
      metadata: %{version: "1.0", test: true}
    }

    # Build the product
    {:ok, product, _new_state} =
      PatternVM.Builder.handle_interaction(
        :build_step_by_step,
        params,
        state
      )

    # Verify the built product
    assert product.name == "Test Product"
    assert length(product.parts) == 3
    assert Enum.member?(product.parts, "part1")
    assert Enum.member?(product.parts, "part2")
    assert Enum.member?(product.parts, "part3")
    assert product.metadata.version == "1.0"
    assert product.metadata.test == true
  end

  test "builder pattern_name returns the expected atom" do
    assert PatternVM.Builder.pattern_name() == :builder
  end
end
