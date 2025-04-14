defmodule PatternVM.CompositeTest do
  use ExUnit.Case

  setup do
    {:ok, state} = PatternVM.Composite.initialize(%{})
    %{state: state}
  end

  test "creates a component", %{state: state} do
    params = %{id: "test1", name: "Test Component", type: :container, data: %{key: "value"}}

    {:ok, component, new_state} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        params,
        state
      )

    assert component.id == "test1"
    assert component.name == "Test Component"
    assert component.type == :container
    assert component.data.key == "value"
    assert component.children == []

    # State should contain the component
    assert Map.has_key?(new_state.composites, "test1")
  end

  test "adds child to parent", %{state: state} do
    # Create parent
    {:ok, _parent, state_with_parent} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "parent", name: "Parent", type: :container},
        state
      )

    # Create child
    {:ok, _child, state_with_both} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "child", name: "Child", type: :item},
        state_with_parent
      )

    # Add child to parent
    {:ok, updated_parent, final_state} =
      PatternVM.Composite.handle_interaction(
        :add_child,
        %{parent_id: "parent", child_id: "child"},
        state_with_both
      )

    # Verify child was added
    assert length(updated_parent.children) == 1
    assert hd(updated_parent.children).id == "child"
    assert hd(updated_parent.children).name == "Child"

    # State should be updated
    assert Map.get(final_state.composites, "parent") == updated_parent
  end

  test "get_component returns the component", %{state: state} do
    # Create component
    {:ok, original, state_with_component} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "test1", name: "Test", type: :item},
        state
      )

    # Get the component
    {:ok, retrieved, ^state_with_component} =
      PatternVM.Composite.handle_interaction(
        :get_component,
        %{id: "test1"},
        state_with_component
      )

    assert retrieved == original
  end

  test "remove_component removes component and from parents", %{state: state} do
    # Create parent
    {:ok, _, state1} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "parent", name: "Parent", type: :container},
        state
      )

    # Create child
    {:ok, _, state2} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "child", name: "Child", type: :item},
        state1
      )

    # Add child to parent
    {:ok, _, state3} =
      PatternVM.Composite.handle_interaction(
        :add_child,
        %{parent_id: "parent", child_id: "child"},
        state2
      )

    # Remove child
    {:ok, removed, final_state} =
      PatternVM.Composite.handle_interaction(
        :remove_component,
        %{id: "child"},
        state3
      )

    # Check removed component
    assert removed.id == "child"

    # Child should be removed from state
    refute Map.has_key?(final_state.composites, "child")

    # Child should be removed from parent
    parent = Map.get(final_state.composites, "parent")
    assert parent.children == []
  end

  test "returns errors for non-existent components", %{state: state} do
    # Try to get non-existent component
    {:error, message1, ^state} =
      PatternVM.Composite.handle_interaction(
        :get_component,
        %{id: "nonexistent"},
        state
      )

    assert message1 =~ "Component not found"

    # Try to add non-existent child
    {:ok, parent, state_with_parent} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "parent", name: "Parent", type: :container},
        state
      )

    {:error, message2, ^state_with_parent} =
      PatternVM.Composite.handle_interaction(
        :add_child,
        %{parent_id: "parent", child_id: "nonexistent"},
        state_with_parent
      )

    assert message2 =~ "Child component not found"

    # Try to add to non-existent parent
    {:error, message3, ^state_with_parent} =
      PatternVM.Composite.handle_interaction(
        :add_child,
        %{parent_id: "nonexistent", child_id: "parent"},
        state_with_parent
      )

    assert message3 =~ "Parent component not found"
  end
end
