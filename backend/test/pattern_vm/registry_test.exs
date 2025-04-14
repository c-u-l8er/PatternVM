defmodule PatternVM.RegistryTest do
  use ExUnit.Case

  setup do
    # Start a fresh Registry for each test
    {:ok, pid} = PatternVM.Registry.start_link([])

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :normal)
    end)

    %{registry_pid: pid}
  end

  test "registers pattern types", %{registry_pid: pid} do
    # Create a mock pattern module
    defmodule MockPattern do
      def pattern_name, do: :mock_pattern
      def initialize(_), do: {:ok, %{}}
    end

    # Register the pattern type
    result = GenServer.call(pid, {:register_type, :mock_pattern, MockPattern})

    assert result == {:ok, :mock_pattern}
  end

  test "registers pattern instances", %{registry_pid: pid} do
    # Create a mock pattern module
    defmodule MockPattern2 do
      def pattern_name, do: :mock_pattern2
      def initialize(config), do: {:ok, config}
    end

    # Register the pattern type
    GenServer.call(pid, {:register_type, :mock_pattern2, MockPattern2})

    # Register an instance
    result =
      GenServer.call(pid, {:register_instance, :my_instance, :mock_pattern2, %{test: true}})

    assert result == {:ok, :my_instance}
  end

  test "returns error for unknown pattern type", %{registry_pid: pid} do
    result = GenServer.call(pid, {:register_instance, :instance, :unknown_type, %{}})

    assert result == {:error, "Unknown pattern type: unknown_type"}
  end
end
