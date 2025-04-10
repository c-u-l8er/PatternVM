defmodule PatternVM.PubSub do
  @moduledoc """
  PubSub service for PatternVM.
  """

  @pubsub_name PatternVM.PubSub

  def child_spec(_opts) do
    # Return the child spec for Phoenix.PubSub directly
    # instead of starting our own supervisor
    Phoenix.PubSub.child_spec(name: @pubsub_name)
  end

  # Client functions
  def subscribe(topic) when is_binary(topic) do
    Phoenix.PubSub.subscribe(@pubsub_name, topic)
  end

  def broadcast(topic, message) when is_binary(topic) do
    Phoenix.PubSub.broadcast(@pubsub_name, topic, message)
  end
end
