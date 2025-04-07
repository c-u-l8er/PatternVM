defmodule PatternVM.DSLTest do
  use ExUnit.Case

  # Define a test module that uses the DSL
  defmodule TestPatterns do
    use PatternVM.DSL

    # Define patterns
    singleton(:config_manager)
    factory(:widget_factory, [:widget, :gadget])
    observer(:quality_control, ["products"])
    builder(:product_builder, ["part1", "part2"])
    strategy(:pricing_strategy, %{standard: :standard_pricing})

    # Define interactions
    interaction(:widget_factory, :create_product, :quality_control, :handle_new_product)

    # Define workflows
    workflow(
      :create_widget,
      sequence([
        create_product(:widget_factory, :widget),
        notify("products", {:context, :last_result})
      ])
    )

    workflow(
      :premium_widget,
      sequence([
        create_product(:widget_factory, :widget),
        build_product(:product_builder, "Premium", ["part1", "part2"], %{premium: true})
      ])
    )
  end

  setup do
    # Mock logger to prevent warnings
    if !Process.whereis(PatternVM.Logger) do
      defmodule PatternVM.Logger do
        def log_interaction(_, _, _), do: :ok
      end
    end

    :ok
  end

  test "DSL correctly registers patterns" do
    patterns = TestPatterns.get_patterns()

    # Verify pattern count and types
    assert length(patterns) == 5

    # Find patterns by name
    config_manager = Enum.find(patterns, fn {name, _, _} -> name == :config_manager end)
    widget_factory = Enum.find(patterns, fn {name, _, _} -> name == :widget_factory end)
    quality_control = Enum.find(patterns, fn {name, _, _} -> name == :quality_control end)

    # Check pattern configurations
    assert config_manager == {:config_manager, :singleton, %{}}
    assert elem(widget_factory, 0) == :widget_factory
    assert elem(widget_factory, 1) == :factory
    assert Map.get(elem(widget_factory, 2), :products) == [:widget, :gadget]
    assert elem(quality_control, 0) == :quality_control
    assert elem(quality_control, 1) == :observer
    assert Map.get(elem(quality_control, 2), :topics) == ["products"]
  end

  test "DSL correctly registers interactions" do
    interactions = TestPatterns.get_interactions()

    # Verify interactions
    assert length(interactions) == 1
    [interaction] = interactions

    assert interaction ==
             {:widget_factory, :create_product, :quality_control, :handle_new_product}
  end

  test "DSL correctly registers workflows" do
    workflows = TestPatterns.get_workflows()

    # Verify workflows
    assert length(workflows) == 2

    # Find workflows by name
    create_widget = Enum.find(workflows, fn {name, _} -> name == :create_widget end)
    premium_widget = Enum.find(workflows, fn {name, _} -> name == :premium_widget end)

    # Check workflow structure
    assert elem(create_widget, 0) == :create_widget
    assert is_tuple(elem(create_widget, 1))
    assert elem(premium_widget, 0) == :premium_widget
    assert is_tuple(elem(premium_widget, 1))
  end
end
