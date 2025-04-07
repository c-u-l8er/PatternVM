defmodule PatternVM.DecoratorTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Decorator.initialize(%{})
    assert state == %{decorators: %{}, name: :decorator}

    # Test with custom config
    {:ok, custom_state} = PatternVM.Decorator.initialize(%{name: :test_decorator})
    assert custom_state == %{decorators: %{}, name: :test_decorator}
  end

  test "register_decorator adds a decorator function" do
    # Initialize decorator pattern
    {:ok, state} = PatternVM.Decorator.initialize(%{})
    decorator_fn = fn obj -> Map.put(obj, :premium, true) end

    # Register a decorator
    {:ok, result, new_state} =
      PatternVM.Decorator.handle_interaction(
        :register_decorator,
        %{name: :premium, decorator_fn: decorator_fn},
        state
      )

    # Verify registration
    assert result == {:registered, :premium}
    assert Map.has_key?(new_state.decorators, :premium)
    assert is_function(new_state.decorators[:premium])
  end

  test "decorate applies multiple decorators" do
    # Initialize decorator pattern
    {:ok, state} = PatternVM.Decorator.initialize(%{})
    premium_fn = fn obj -> Map.put(obj, :premium, true) end
    sale_fn = fn obj -> Map.put(obj, :on_sale, true) end

    # Register decorators
    {:ok, _, state_with_premium} =
      PatternVM.Decorator.handle_interaction(
        :register_decorator,
        %{name: :premium, decorator_fn: premium_fn},
        state
      )

    {:ok, _, state_with_both} =
      PatternVM.Decorator.handle_interaction(
        :register_decorator,
        %{name: :sale, decorator_fn: sale_fn},
        state_with_premium
      )

    # Apply multiple decorators
    {:ok, result, _} =
      PatternVM.Decorator.handle_interaction(
        :decorate,
        %{object: %{base: true}, decorators: [:premium, :sale]},
        state_with_both
      )

    # Verify decoration
    assert result.base == true
    assert result.premium == true
    assert result.on_sale == true
  end

  test "decorate with nonexistent decorator returns error" do
    # Initialize decorator pattern
    {:ok, state} = PatternVM.Decorator.initialize(%{})

    # Try to use a non-existent decorator
    {:error, errors, _} =
      PatternVM.Decorator.handle_interaction(
        :decorate,
        %{object: %{}, decorators: [:nonexistent]},
        state
      )

    # Verify error
    assert Enum.member?(errors, "Decorator not found: nonexistent")
  end

  test "decorator pattern_name returns the expected atom" do
    assert PatternVM.Decorator.pattern_name() == :decorator
  end
end
