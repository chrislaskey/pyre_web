defmodule PyreWeb.Channel do
  @moduledoc """
  Phoenix Channel for Pyre native app communication.

  Handles channel joins and incoming messages from the Pyre native app
  over the `pyre:*` topic namespace.

  ## Topics

  - `pyre:hello` — basic connectivity check, returns a greeting on join
  - `pyre:connections` — presence tracking for connected native apps
  """
  use Phoenix.Channel

  require Logger

  @impl true
  def join("pyre:hello", _params, socket) do
    {:ok, %{message: "hello world"}, socket}
  end

  def join("pyre:connections", params, socket) do
    send(self(), :after_join)

    metadata = %{
      name: params["name"] || "Unknown",
      cpu_cores: params["cpu_cores"],
      cpu_brand: params["cpu_brand"],
      memory_gb: params["memory_gb"],
      os_version: params["os_version"]
    }

    socket = assign(socket, :connection_metadata, metadata)

    {:ok, %{message: "connected"}, socket}
  end

  def join("pyre:" <> _topic, _params, _socket) do
    {:error, %{reason: "unknown topic"}}
  end

  @impl true
  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{message: "pong"}}, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    if PyreWeb.Presence.running?() do
      connection_id = socket.assigns[:connection_id] || socket.id || "anonymous"
      metadata = socket.assigns[:connection_metadata] || %{}

      {:ok, _} = PyreWeb.Presence.track(socket, connection_id, metadata)
    end

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"} = msg, socket) do
    push(socket, "presence_diff", msg.payload)
    {:noreply, socket}
  end
end
