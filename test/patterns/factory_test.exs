defmodule PatternVM.FactoryTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Factory.initialize(%{})
    assert state == %{products_created: 0}
  end

  test "create_product creates expected products" do
    # Initialize the factory
    {:ok, state} = PatternVM.Factory.initialize(%{})

    # Create a widget
    {:ok, widget, new_state} =
      PatternVM.Factory.handle_interaction(
        :create_product,
        %{type: :widget},
        state
      )

    # Verify product and updated state
    assert widget.type == :widget
    assert widget.id != nil
    assert widget.created_at != nil
    assert new_state.products_created == 1

    # Create another product
    {:ok, gadget, newer_state} =
      PatternVM.Factory.handle_interaction(
        :create_product,
        %{type: :gadget},
        new_state
      )

    assert gadget.type == :gadget
    assert newer_state.products_created == 2
  end

  test "factory pattern_name returns the expected atom" do
    assert PatternVM.Factory.pattern_name() == :factory
  end
end
