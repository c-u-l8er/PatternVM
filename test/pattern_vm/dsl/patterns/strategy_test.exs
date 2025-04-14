defmodule PatternVM.DSL.StrategyTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  # Define strategy functions with proper reference format
  def discount_strategy(product) do
    %{price: product.price * 0.9, name: product.name, discounted: true}
  end

  def premium_strategy(product) do
    %{price: product.price * 1.2, name: product.name, premium: true}
  end

  # Define the double strategy function
  def double_strategy(args) do
    %{result: args.value * 2}
  end

  test "strategy pattern definition and execution" do
    defmodule StrategyExample do
      use PatternVM.DSL
      import PatternVM.DSL.StrategyTest, only: []

      # Define strategy pattern with strategies using direct function references
      # to avoid serialization issues
      workflow(
        :register_strategies,
        sequence([
          {:interact, :pricing_strategy, :register_strategy,
           %{
             name: :discount,
             function: &PatternVM.DSL.StrategyTest.discount_strategy/1
           }},
          {:interact, :pricing_strategy, :register_strategy,
           %{
             name: :premium,
             function: &PatternVM.DSL.StrategyTest.premium_strategy/1
           }}
        ])
      )

      # Define workflow for applying discount strategy
      workflow(
        :apply_discount,
        sequence([
          execute_strategy(:pricing_strategy, :discount, %{name: "Widget", price: 100})
        ])
      )

      # Define workflow for applying premium strategy
      workflow(
        :apply_premium,
        sequence([
          execute_strategy(:pricing_strategy, :premium, %{name: "Widget", price: 100})
        ])
      )
    end

    # Execute definition and register pattern
    StrategyExample.execute()
    PatternVM.register_pattern(PatternVM.Strategy, %{name: :pricing_strategy})

    # Register strategies first
    PatternVM.DSL.Runtime.execute_workflow(StrategyExample, :register_strategies)

    # Test discount strategy
    result1 = PatternVM.DSL.Runtime.execute_workflow(StrategyExample, :apply_discount)
    # 10% discount
    assert result1.last_result.price == 90.0
    assert result1.last_result.discounted == true

    # Test premium strategy
    result2 = PatternVM.DSL.Runtime.execute_workflow(StrategyExample, :apply_premium)
    # 20% increase
    assert result2.last_result.price == 120.0
    assert result2.last_result.premium == true
  end

  test "registering strategies at runtime" do
    defmodule RuntimeStrategyExample do
      use PatternVM.DSL

      # Define workflow to register a strategy
      workflow(
        :register_strategy,
        sequence([
          {:interact, :runtime_strategy, :register_strategy,
           %{
             name: :double,
             function: &PatternVM.DSL.StrategyTest.double_strategy/1
           }}
        ])
      )

      # Workflow to execute the registered strategy
      workflow(
        :execute_registered,
        sequence([
          execute_strategy(:runtime_strategy, :double, %{value: 5})
        ])
      )
    end

    # Execute definition
    RuntimeStrategyExample.execute()

    # Register the strategy pattern first
    PatternVM.register_pattern(PatternVM.Strategy, %{name: :runtime_strategy})

    # Register the strategy
    PatternVM.DSL.Runtime.execute_workflow(RuntimeStrategyExample, :register_strategy)

    # Execute the registered strategy
    result = PatternVM.DSL.Runtime.execute_workflow(RuntimeStrategyExample, :execute_registered)
    # 5 doubled
    assert result.last_result.result == 10
  end
end
