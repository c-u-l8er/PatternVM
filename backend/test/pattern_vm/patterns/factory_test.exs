defmodule PatternVM.FactoryTest do
  use ExUnit.Case

  # Ensure mock UUID is used
  setup do
    {:ok, state} = PatternVM.Factory.initialize(%{})
    %{state: state}
  end

  test "creates different product types", %{state: state} do
    {:ok, widget, _state} =
      PatternVM.Factory.handle_interaction(:create_product, %{type: :widget}, state)

    {:ok, gadget, _state} =
      PatternVM.Factory.handle_interaction(:create_product, %{type: :gadget}, state)

    {:ok, tool, _state} =
      PatternVM.Factory.handle_interaction(:create_product, %{type: :tool}, state)

    assert widget.type == :widget
    assert gadget.type == :gadget
    assert tool.type == :tool

    # Ensure different IDs
    assert widget.id != gadget.id
    assert gadget.id != tool.id
  end

  test "tracks products created", %{state: state} do
    assert state.products_created == 0

    {:ok, _product, new_state} =
      PatternVM.Factory.handle_interaction(:create_product, %{type: :widget}, state)

    assert new_state.products_created == 1

    {:ok, _product, newer_state} =
      PatternVM.Factory.handle_interaction(:create_product, %{type: :gadget}, new_state)

    assert newer_state.products_created == 2
  end
end
