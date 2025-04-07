defmodule PatternVM.CompositeTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Composite.initialize(%{})
    assert state == %{composites: %{}, name: :composite}

    # Test with custom config
    {:ok, custom_state} = PatternVM.Composite.initialize(%{name: :test_composite})
    assert custom_state == %{composites: %{}, name: :test_composite}
  end

  test "create_component creates a component" do
    # Initialize composite pattern
    {:ok, state} = PatternVM.Composite.initialize(%{})

    # Create a component
    params = %{id: "1", name: "Root", type: :container, data: %{key: "value"}}

    {:ok, component, new_state} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        params,
        state
      )

    # Verify component creation
    assert component.id == "1"
    assert component.name == "Root"
    assert component.type == :container
    assert component.data.key == "value"
    assert component.children == []
    assert Map.has_key?(new_state.composites, "1")
    assert new_state.composites["1"] == component
  end

  test "add_child establishes parent-child relationship" do
    # Initialize composite pattern
    {:ok, state} = PatternVM.Composite.initialize(%{})

    # Create parent and child components
    {:ok, parent, state_with_parent} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "parent", name: "Parent", type: :container},
        state
      )

    {:ok, child, state_with_both} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "child", name: "Child", type: :item},
        state_with_parent
      )

    # Add child to parent
    {:ok, updated_parent, new_state} =
      PatternVM.Composite.handle_interaction(
        :add_child,
        %{parent_id: "parent", child_id: "child"},
        state_with_both
      )

    # Verify relationship
    assert length(updated_parent.children) == 1
    [added_child] = updated_parent.children
    assert added_child.id == "child"
    assert added_child.name == "Child"
    assert new_state.composites["parent"] == updated_parent
  end

  test "get_component retrieves a component" do
    # Initialize composite pattern with a component
    {:ok, state} = PatternVM.Composite.initialize(%{})

    {:ok, _, state_with_component} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "1", name: "Component", type: :item},
        state
      )

    # Get the component
    {:ok, component, _} =
      PatternVM.Composite.handle_interaction(
        :get_component,
        %{id: "1"},
        state_with_component
      )

    # Verify component retrieval
    assert component.id == "1"
    assert component.name == "Component"
    assert component.type == :item
  end

  test "get_component with nonexistent ID returns error" do
    # Initialize composite pattern
    {:ok, state} = PatternVM.Composite.initialize(%{})

    # Try to get a nonexistent component
    {:error, message, _} =
      PatternVM.Composite.handle_interaction(
        :get_component,
        %{id: "nonexistent"},
        state
      )

    # Verify error
    assert message == "Component not found: nonexistent"
  end

  test "remove_component removes a component and its references" do
    # Initialize composite with parent-child relationship
    {:ok, state} = PatternVM.Composite.initialize(%{})

    {:ok, _, state_with_parent} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "parent", name: "Parent", type: :container},
        state
      )

    {:ok, _, state_with_both} =
      PatternVM.Composite.handle_interaction(
        :create_component,
        %{id: "child", name: "Child", type: :item},
        state_with_parent
      )

    {:ok, _, state_with_relationship} =
      PatternVM.Composite.handle_interaction(
        :add_child,
        %{parent_id: "parent", child_id: "child"},
        state_with_both
      )

    # Remove the child
    {:ok, removed, new_state} =
      PatternVM.Composite.handle_interaction(
        :remove_component,
        %{id: "child"},
        state_with_relationship
      )

    # Verify removal and parent update
    assert removed.id == "child"
    assert !Map.has_key?(new_state.composites, "child")
    assert new_state.composites["parent"].children == []
  end

  test "composite pattern_name returns the expected atom" do
    assert PatternVM.Composite.pattern_name() == :composite
  end
end
