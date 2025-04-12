defmodule PatternVM.SupervisorTest do
  use ExUnit.Case

  setup do
    # Make sure the test flag is set
    Application.put_env(:pattern_vm, :testing, true)

    # Make sure ETS table exists
    if :ets.whereis(:pattern_vm_children) == :undefined do
      :ets.new(:pattern_vm_children, [:named_table, :public])
    end

    # Start the supervisor
    {:ok, pid} = PatternVM.Supervisor.start_link([])

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :normal)
    end)

    %{supervisor_pid: pid}
  end

  test "starts child processes", %{supervisor_pid: pid} do
    # Define a simple worker module
    defmodule TestWorker do
      use GenServer

      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(args) do
        {:ok, args}
      end
    end

    # Start a child process
    {:ok, child_pid} = PatternVM.Supervisor.start_child(TestWorker, %{test: true})

    # Check that child is running
    assert Process.alive?(child_pid)

    # Check that child is registered in the ETS table
    [{^child_pid, {module, args}}] = :ets.lookup(:pattern_vm_children, child_pid)
    assert module == TestWorker
    assert args == %{test: true}
  end

  test "handles process failures gracefully" do
    defmodule FailingWorker do
      use GenServer

      def start_link(_) do
        GenServer.start_link(__MODULE__, [])
      end

      def init(_) do
        # Simulate initialization failure
        {:error, "Intentional failure"}
      end
    end

    # Try to start the failing worker
    result = PatternVM.Supervisor.start_child(FailingWorker, %{})

    # Should return error from init
    assert result == {:error, "Intentional failure"}
  end
end
