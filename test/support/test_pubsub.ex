defmodule PatternVM.TestPubSub do
  @moduledoc """
  A simple in-memory implementation of PubSub for testing.
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{subscriptions: %{}}}
  end

  def subscribe(topic) do
    GenServer.call(__MODULE__, {:subscribe, topic, self()})
  end

  def broadcast(topic, message) do
    GenServer.cast(__MODULE__, {:broadcast, topic, message})
  end

  def handle_call({:subscribe, topic, pid}, _from, state) do
    subscribers = Map.get(state.subscriptions, topic, [])
    updated_subscribers = [pid | subscribers]
    updated_subscriptions = Map.put(state.subscriptions, topic, updated_subscribers)
    {:reply, :ok, %{state | subscriptions: updated_subscriptions}}
  end

  def handle_cast({:broadcast, topic, message}, state) do
    subscribers = Map.get(state.subscriptions, topic, [])

    Enum.each(subscribers, fn pid ->
      send(pid, message)
    end)

    {:noreply, state}
  end
end
