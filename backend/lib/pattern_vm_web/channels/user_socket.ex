defmodule PatternVMWeb.UserSocket do
  use Phoenix.Socket

  # Define all channels that can be joined
  channel "pattern:*", PatternVMWeb.PatternChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
