defmodule PatternVM.TestHelpers do
  @moduledoc """
  Helper functions for testing PatternVM.
  """

  def setup_test_environment do
    # Setup logger mock if not available
    unless Process.whereis(PatternVM.Logger) do
      Module.create(
        PatternVM.Logger,
        quote do
          def log_interaction(_, _, _), do: :ok
        end,
        Macro.Env.location(__ENV__)
      )
    end

    # Setup supervisor mock if not available
    unless Process.whereis(PatternVM.Supervisor) do
      Module.create(
        PatternVM.Supervisor,
        quote do
          def start_child(_, _), do: {:ok, spawn(fn -> :ok end)}
        end,
        Macro.Env.location(__ENV__)
      )
    end

    # Setup UUID mock if not available
    unless Code.ensure_loaded?(UUID) do
      Module.create(
        UUID,
        quote do
          def uuid4, do: "test-uuid-#{:erlang.unique_integer([:positive])}"
        end,
        Macro.Env.location(__ENV__)
      )
    end

    # Setup PubSub mock
    unless Process.whereis(Phoenix.PubSub) do
      Module.create(
        Phoenix.PubSub,
        quote do
          def subscribe(_, _), do: :ok
          def broadcast(_, _, _), do: :ok
        end,
        Macro.Env.location(__ENV__)
      )
    end

    :ok
  end
end
