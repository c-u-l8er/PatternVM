defmodule PatternVMWeb.PatternChannel do
  use Phoenix.Channel

  def join("pattern:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("pattern:" <> pattern_name, _params, socket) do
    # Subscribe to pattern-specific events
    Phoenix.PubSub.subscribe(PatternVM.PubSub, "pattern_events:#{pattern_name}")
    {:ok, socket}
  end

  # Handle messages coming from the client
  def handle_in("interact", %{"pattern" => pattern, "action" => action, "params" => params}, socket) do
    pattern_atom = String.to_atom(pattern)
    action_atom = String.to_atom(action)

    # Convert string keys to atoms (with safety constraints)
    processed_params = process_params(params)

    case PatternVM.interact(pattern_atom, action_atom, processed_params) do
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}

      result ->
        {:reply, {:ok, %{result: result}}, socket}
    end
  end

  # Forward pattern events to connected clients
  def handle_info({:pattern_event, event}, socket) do
    push(socket, "pattern_event", event)
    {:noreply, socket}
  end

  # Parameter processing (same as in InteractionController)
  defp process_params(params) when is_map(params) do
    # Implementation as in InteractionController
  end

  defp process_params(params) when is_list(params) do
    Enum.map(params, &process_params/1)
  end

  defp process_params(params), do: params
end
