defmodule PatternVM.Logger do
  @moduledoc """
  Centralized logging for pattern interactions.
  """

  def log_interaction(source, action, data) do
    message = "[#{source}] #{action}: #{inspect(data)}"

    # Write to console in development
    if Mix.env() in [:dev, :test] do
      IO.puts(message)
    end

    # Could be extended to publish to PubSub, write to database, etc.

    :ok
  end
end
