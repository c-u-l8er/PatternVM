defmodule PatternVM.Supervisor do
  @moduledoc """
  Supervisor for PatternVM processes.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      # Add your child specifications here
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_child(module, args) do
    # This approach would be better with a DynamicSupervisor
    spec = %{
      id: make_ref(),
      start: {module, :start_link, [args]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }

    Supervisor.start_child(__MODULE__, spec)
  end
end
