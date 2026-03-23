defmodule PyreWeb.HomeLive do
  @moduledoc """
  Landing page for the PyreWeb interface.
  """
  use PyreWeb.Web, :live_view

  @presence_topic "pyre:connections"

  @impl true
  def mount(_params, _session, socket) do
    presences =
      if connected?(socket) and PyreWeb.Presence.running?() do
        Phoenix.PubSub.subscribe(pubsub(), @presence_topic)
        PyreWeb.Presence.list_connections()
      else
        []
      end

    {:ok, assign(socket, page_title: "Pyre", presences: presences)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    presences = update_presences(socket.assigns.presences, diff)
    {:noreply, assign(socket, :presences, presences)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-8 max-w-6xl mx-auto px-4">
      <h1 class="mb-3 text-xl font-bold">Pyre</h1>
      <p class="text-base-content/80">Multi-agent LLM framework for Phoenix development.</p>
      <p class="text-base-content/50 text-sm mb-6">Pyre v{pyre_version()}</p>

      <div class="flex gap-3">
        <.link navigate={pyre_path(@socket, "/runs/new")} class="btn btn-primary">
          Start a New Run
        </.link>
        <.link navigate={pyre_path(@socket, "/runs")} class="btn btn-outline">View Runs</.link>
      </div>

      <.live_component
        module={PyreWeb.ConnectionPresenceComponent}
        id="connection-presence"
        presences={@presences}
      />
    </div>
    """
  end

  defp pyre_version do
    case Application.spec(:pyre, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
  end

  defp pubsub do
    Application.get_env(:pyre, :pubsub, Phoenix.PubSub)
  end

  defp update_presences(presences, %{joins: joins, leaves: leaves}) do
    leave_ids = Map.keys(leaves) |> MapSet.new()

    remaining = Enum.reject(presences, &MapSet.member?(leave_ids, &1.connection_id))

    new =
      Enum.map(joins, fn {connection_id, %{metas: [meta | _]}} ->
        Map.put(meta, :connection_id, connection_id)
      end)

    remaining ++ new
  end
end
