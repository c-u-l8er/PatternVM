defmodule PatternVM.Observer do
  use GenServer
  @behaviour PatternVM.PatternBehavior

  # Pattern Behavior Implementation
  def pattern_name, do: :observer

  def initialize(config) do
    {:ok, %{topics: Map.get(config, :topics, []), callbacks: Map.get(config, :callbacks, %{})}}
  end

  def handle_interaction(:subscribe, %{topic: topic, callback: callback}, state) do
    updated_topics = [topic | state.topics] |> Enum.uniq()
    updated_callbacks = Map.put(state.callbacks, topic, callback)
    new_state = %{state | topics: updated_topics, callbacks: updated_callbacks}

    # Subscribe to the topic with error handling
    case PatternVM.PubSub.subscribe(topic) do
      :ok ->
        PatternVM.Logger.log_interaction("Observer", "subscribe", %{topic: topic})
        {:ok, {:subscribed, topic}, new_state}

      error ->
        PatternVM.Logger.log_interaction("Observer", "subscribe_error", %{
          topic: topic,
          error: error
        })

        {:error, "Could not subscribe to topic #{topic}: #{inspect(error)}", state}
    end
  end

  # Client API
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    state = %{
      topics: args[:topics] || [],
      callbacks: args[:callbacks] || %{}
    }

    # Subscribe to topics with a delay to ensure PubSub is initialized
    if state.topics != [] do
      Process.send_after(self(), :subscribe_to_topics, 100)
    end

    {:ok, state}
  end

  def handle_info(:subscribe_to_topics, state) do
    # Try to subscribe to all topics, log any errors but don't crash
    Enum.each(state.topics, fn topic ->
      case PatternVM.PubSub.subscribe(topic) do
        :ok ->
          PatternVM.Logger.log_interaction("Observer", "initial_subscribe", %{topic: topic})

        error ->
          PatternVM.Logger.log_interaction("Observer", "initial_subscribe_error", %{
            topic: topic,
            error: error
          })
      end
    end)

    {:noreply, state}
  end

  def handle_info({:update, data} = message, state) do
    topic = data[:topic] || "unknown"

    # Execute callback if defined
    if Map.has_key?(state.callbacks, topic) do
      callback = state.callbacks[topic]
      callback.(data)
    end

    PatternVM.Logger.log_interaction("Observer", "received_update", %{topic: topic, data: data})
    {:noreply, state}
  end

  def handle_info({:log, _log_entry}, state) do
    # Just ignore log entries to avoid loops
    {:noreply, state}
  end

  def handle_info(message, state) do
    # Handle any other messages
    PatternVM.Logger.log_interaction("Observer", "unknown_message", %{message: message})
    {:noreply, state}
  end
end
