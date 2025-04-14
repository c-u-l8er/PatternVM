defmodule PatternVM.SingletonTest do
  use ExUnit.Case

  setup do
    # Start a fresh Singleton instance for each test
    {:ok, state} = PatternVM.Singleton.initialize(%{instance: "Test Instance"})
    %{state: state}
  end

  test "returns the same instance every time", %{state: state} do
    {:ok, instance1, ^state} = PatternVM.Singleton.handle_interaction(:get_instance, %{}, state)
    {:ok, instance2, ^state} = PatternVM.Singleton.handle_interaction(:get_instance, %{}, state)

    assert instance1 == "Test Instance"
    assert instance2 == "Test Instance"
    assert instance1 == instance2
  end

  test "maintains singleton state", %{state: state} do
    new_state = %{state | instance: "Modified Instance"}

    {:ok, instance, ^new_state} =
      PatternVM.Singleton.handle_interaction(:get_instance, %{}, new_state)

    assert instance == "Modified Instance"
  end
end
