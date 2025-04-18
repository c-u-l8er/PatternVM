defmodule PatternVM.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    # Create ETS table for testing if we're in testing mode
    if Application.get_env(:pattern_vm, :testing, false) do
      :ets.new(:pattern_vm_children, [:named_table, :public])
    end

    children = []
    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_child(module, args) do
    spec = %{
      id: make_ref(),
      start: {module, :start_link, [args]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }

    case Supervisor.start_child(__MODULE__, spec) do
      {:ok, pid} = result ->
        # Store in ETS table for test introspection
        if Application.get_env(:pattern_vm, :testing, false) do
          # Only try to insert if the table exists
          try do
            :ets.insert(:pattern_vm_children, {pid, {module, args}})
          rescue
            # Ignore if table doesn't exist
            _ -> :ok
          end
        end

        result

      other ->
        other
    end
  end
end
