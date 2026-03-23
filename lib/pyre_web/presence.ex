defmodule PyreWeb.Presence do
  @moduledoc """
  Tracks connected Pyre native app instances via Phoenix.Presence.

  Uses the PubSub server configured via `config :pyre, :pubsub` — no
  additional Presence-specific configuration is needed.

  ## Host App Setup

  Add `PyreWeb.Presence` to your supervision tree:

      # lib/my_app/application.ex
      children = [
        # ... existing children ...
        PyreWeb.Presence
      ]
  """
  use Phoenix.Presence,
    otp_app: :pyre_web,
    pubsub_server: Phoenix.PubSub

  defoverridable child_spec: 1

  @topic "pyre:connections"

  @doc false
  def child_spec(opts) do
    pubsub = Application.get_env(:pyre, :pubsub)

    if pubsub do
      Application.put_env(:pyre_web, __MODULE__, pubsub_server: pubsub)
    end

    super(opts)
  end

  @doc """
  Returns simplified presence data for the connections topic.

  Each entry is a map with `:connection_id` and the metadata sent on join
  (name, cpu_cores, cpu_brand, memory_gb, os_version).
  """
  def list_connections do
    @topic
    |> list()
    |> Enum.map(fn {connection_id, %{metas: [meta | _]}} ->
      Map.put(meta, :connection_id, connection_id)
    end)
  end
end
