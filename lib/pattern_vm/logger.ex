defmodule PatternVM.Logger do
  @moduledoc """
  Centralized logging for pattern interactions.
  """

  def log_interaction(source, action, data) do
    message = "[#{source}] #{action}: #{inspect(data)}"

    # Write to console in development
    if Application.get_env(:pattern_vm, :log_to_console, Mix.env() == :dev) do
      IO.puts(message)
    end

    # Optionally log to a test accumulator in test environment
    if Mix.env() == :test do
      log_to_test_accumulator(source, action, data)
    end

    # Broadcast the log event through PubSub for visualization
    try do
      PatternVM.PubSub.broadcast(
        "pattern_logs",
        {:log,
         %{
           source: source,
           action: action,
           data: data,
           timestamp: DateTime.utc_now()
         }}
      )
    rescue
      # Silently fail if PubSub isn't available
      _ -> :ok
    end

    :ok
  end

  defp log_to_test_accumulator(source, action, data) do
    # Store in process dictionary for easy testing
    logs = Process.get(:test_pattern_logs, [])
    updated_logs = [{source, action, data} | logs]
    Process.put(:test_pattern_logs, updated_logs)
  end

  def get_test_logs do
    Process.get(:test_pattern_logs, [])
  end

  def clear_test_logs do
    Process.put(:test_pattern_logs, [])
  end
end
