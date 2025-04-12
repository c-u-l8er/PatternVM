defmodule PatternVM.DSL.CompositeTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "composite pattern definition and structure building" do
    defmodule CompositeExample do
      use PatternVM.DSL

      # Define composite pattern
      composite(:file_system)

      # Define workflow for creating a simple hierarchy
      workflow(
        :create_simple_tree,
        sequence([
          # Create root folder
          create_component(:file_system, "root", "Root Folder", :folder),

          # Create a subfolder and a document
          create_component(:file_system, "docs", "Documents", :folder),
          create_component(:file_system, "note", "Note.txt", :file, %{content: "Hello World"}),

          # Build the hierarchy
          add_child(:file_system, "root", "docs"),
          add_child(:file_system, "docs", "note"),

          # Get the root to see the full structure
          {:interact, :file_system, :get_component, %{id: "root"}}
        ])
      )
    end

    # Execute definition
    CompositeExample.execute()

    # Create the tree structure
    result = PatternVM.DSL.Runtime.execute_workflow(CompositeExample, :create_simple_tree)

    # Verify root structure
    root = result.last_result
    assert root.id == "root"
    assert root.name == "Root Folder"
    assert root.type == :folder

    # Should have one child (docs)
    assert length(root.children) == 1
    docs = hd(root.children)
    assert docs.id == "docs"

    # Docs should have one child (note)
    assert length(docs.children) == 1
    note = hd(docs.children)
    assert note.id == "note"
    assert note.type == :file
    assert note.data.content == "Hello World"
  end

  test "modifying composite structure" do
    defmodule ModifyCompositeExample do
      use PatternVM.DSL

      composite(:project)

      # Workflow to build and then modify a structure
      workflow(
        :build_and_modify,
        sequence([
          # Create initial structure
          create_component(:project, "proj", "Project", :root),
          create_component(:project, "src", "Source", :folder),
          create_component(:project, "test", "Tests", :folder),
          create_component(:project, "main", "Main.ex", :file),

          # Build hierarchy
          add_child(:project, "proj", "src"),
          add_child(:project, "proj", "test"),
          add_child(:project, "src", "main"),

          # Store initial structure
          {:interact, :project, :get_component, %{id: "proj"}},
          {:store, :initial_structure, :last_result},

          # Remove a component
          {:interact, :project, :remove_component, %{id: "main"}},

          # Get final structure
          {:interact, :project, :get_component, %{id: "proj"}}
        ])
      )
    end

    # Execute definition
    ModifyCompositeExample.execute()

    # Run the workflow
    result = PatternVM.DSL.Runtime.execute_workflow(ModifyCompositeExample, :build_and_modify)

    # Check initial structure
    initial = result.initial_structure
    src = Enum.find(initial.children, fn c -> c.id == "src" end)
    assert length(src.children) == 1

    # Check final structure (main should be removed)
    final = result.last_result
    src_final = Enum.find(final.children, fn c -> c.id == "src" end)
    assert src_final.children == []
  end

  test "deep composite hierarchy" do
    defmodule DeepCompositeExample do
      use PatternVM.DSL

      composite(:deep_tree)

      # Define workflow for creating a deeper hierarchy
      workflow(
        :create_deep_tree,
        sequence([
          # Create components
          create_component(:deep_tree, "root", "Root", :root),
          create_component(:deep_tree, "level1", "Level 1", :node),
          create_component(:deep_tree, "level2", "Level 2", :node),
          create_component(:deep_tree, "level3", "Level 3", :node),
          create_component(:deep_tree, "leaf", "Leaf", :leaf),

          # Build hierarchy
          add_child(:deep_tree, "root", "level1"),
          add_child(:deep_tree, "level1", "level2"),
          add_child(:deep_tree, "level2", "level3"),
          add_child(:deep_tree, "level3", "leaf"),

          # Get the structure
          {:interact, :deep_tree, :get_component, %{id: "root"}}
        ])
      )
    end

    # Execute definition
    DeepCompositeExample.execute()

    # Create the deep tree
    result = PatternVM.DSL.Runtime.execute_workflow(DeepCompositeExample, :create_deep_tree)

    # Navigate through the hierarchy to verify structure
    root = result.last_result
    assert root.id == "root"

    level1 = hd(root.children)
    assert level1.id == "level1"

    level2 = hd(level1.children)
    assert level2.id == "level2"

    level3 = hd(level2.children)
    assert level3.id == "level3"

    leaf = hd(level3.children)
    assert leaf.id == "leaf"
    assert leaf.type == :leaf
  end
end
