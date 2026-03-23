defmodule PyreWeb.Channel do
  @moduledoc """
  Phoenix Channel for Pyre native app communication.

  Handles channel joins and incoming messages from the Pyre native app
  over the `pyre:*` topic namespace.

  ## Topics

  - `pyre:hello` — basic connectivity check, returns a greeting on join
  """
  use Phoenix.Channel

  require Logger

  @impl true
  def join("pyre:hello", _params, socket) do
    {:ok, %{message: "hello world"}, socket}
  end

  def join("pyre:" <> _topic, _params, _socket) do
    {:error, %{reason: "unknown topic"}}
  end

  @impl true
  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{message: "pong"}}, socket}
  end
end
