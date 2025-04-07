defmodule PatternVM.SingletonTest do
  use ExUnit.Case

  setup do
    PatternVM.TestHelpers.setup_test_environment()
    {:ok, pid} = PatternVM.start_link([])
    %{pattern_vm_pid: pid}
  end

  test "initialize returns expected state" do
    {:ok, state} = PatternVM.Singleton.initialize(%{})
    assert state == %{instance: "I am the Singleton"}

    # Test with custom config
    {:ok, custom_state} = PatternVM.Singleton.initialize(%{instance: "Custom Singleton"})
    assert custom_state == %{instance: "Custom Singleton"}
  end

  test "get_instance returns the singleton instance" do
    {:ok, state} = PatternVM.Singleton.initialize(%{})
    {:ok, instance, ^state} = PatternVM.Singleton.handle_interaction(:get_instance, %{}, state)
    assert instance == "I am the Singleton"
  end

  test "singleton pattern_name returns the expected atom" do
    assert PatternVM.Singleton.pattern_name() == :singleton
  end
end
