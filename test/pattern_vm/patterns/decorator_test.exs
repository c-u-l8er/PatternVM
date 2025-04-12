defmodule PatternVM.DecoratorTest do
  use ExUnit.Case

  setup do
    decorators = %{
      uppercase: fn str -> String.upcase(str) end,
      add_exclamation: fn str -> "#{str}!" end
    }

    {:ok, state} = PatternVM.Decorator.initialize(%{decorators: decorators})
    %{state: state}
  end

  test "applies single decorator", %{state: state} do
    {:ok, result, ^state} =
      PatternVM.Decorator.handle_interaction(
        :decorate,
        %{
          object: "hello",
          decorators: [:uppercase]
        },
        state
      )

    assert result == "HELLO"
  end

  test "applies multiple decorators in sequence", %{state: state} do
    {:ok, result, ^state} =
      PatternVM.Decorator.handle_interaction(
        :decorate,
        %{
          object: "hello",
          decorators: [:uppercase, :add_exclamation]
        },
        state
      )

    # First uppercase, then add exclamation
    assert result == "HELLO!"
  end

  test "registers and uses new decorator", %{state: state} do
    new_decorator = fn str -> "<#{str}>" end

    # Register decorator
    {:ok, {:registered, :brackets}, new_state} =
      PatternVM.Decorator.handle_interaction(
        :register_decorator,
        %{
          name: :brackets,
          decorator_fn: new_decorator
        },
        state
      )

    # Use all decorators including new one
    {:ok, result, ^new_state} =
      PatternVM.Decorator.handle_interaction(
        :decorate,
        %{
          object: "hello",
          decorators: [:uppercase, :brackets, :add_exclamation]
        },
        new_state
      )

    assert result == "<HELLO>!"
  end

  test "returns error for unknown decorators", %{state: state} do
    {:error, errors, ^state} =
      PatternVM.Decorator.handle_interaction(
        :decorate,
        %{
          object: "hello",
          decorators: [:unknown_decorator]
        },
        state
      )

    assert length(errors) == 1
    assert hd(errors) =~ "Decorator not found: unknown_decorator"
  end

  test "handles combination of known and unknown decorators", %{state: state} do
    {:error, errors, ^state} =
      PatternVM.Decorator.handle_interaction(
        :decorate,
        %{
          object: "hello",
          decorators: [:uppercase, :unknown, :another_unknown]
        },
        state
      )

    assert length(errors) == 2
    assert Enum.at(errors, 0) =~ "another_unknown"
    assert Enum.at(errors, 1) =~ "unknown"
  end
end
