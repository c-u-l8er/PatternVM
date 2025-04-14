defmodule PatternVM.LoggerTest do
  use ExUnit.Case

  setup do
    # Clear test logs before each test
    PatternVM.Logger.clear_test_logs()
    :ok
  end

  test "logs interactions and stores them for testing" do
    PatternVM.Logger.log_interaction("TestPattern", "test_action", %{data: "test"})

    logs = PatternVM.Logger.get_test_logs()
    assert length(logs) == 1

    {source, action, data} = hd(logs)
    assert source == "TestPattern"
    assert action == "test_action"
    assert data.data == "test"
  end

  test "accumulates multiple logs" do
    PatternVM.Logger.log_interaction("Source1", "action1", %{})
    PatternVM.Logger.log_interaction("Source2", "action2", %{})
    PatternVM.Logger.log_interaction("Source3", "action3", %{})

    logs = PatternVM.Logger.get_test_logs()
    assert length(logs) == 3

    # Logs are stored in reverse order (most recent first)
    sources = Enum.map(logs, fn {src, _, _} -> src end)
    assert sources == ["Source3", "Source2", "Source1"]
  end

  test "clears logs" do
    PatternVM.Logger.log_interaction("Test", "action", %{})
    assert length(PatternVM.Logger.get_test_logs()) == 1

    PatternVM.Logger.clear_test_logs()
    assert PatternVM.Logger.get_test_logs() == []
  end
end
