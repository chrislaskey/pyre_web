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

    {:ok,
     socket
     |> assign(page_title: "Pyre", presences: presences)
     |> assign(execution: nil, action_output: [])}
  end

  @impl true
  def handle_event("action_execute_commands_clone_repo", %{"connection-id" => connection_id}, socket) do
    execution_id = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    pubsub = pubsub()

    # Subscribe to output from this execution
    Phoenix.PubSub.subscribe(pubsub, "pyre:action:output:#{execution_id}")

    action = %{
      type: "execute_commands",
      payload: %{
        commands: [
          "mkdir -p ~/code/pyre-runtime",
          "git -C ~/code/pyre-runtime/pyre pull || git clone https://github.com/chrislaskey/pyre ~/code/pyre-runtime/pyre"
        ]
      }
    }

    # Send to the connection's channel via PubSub
    Phoenix.PubSub.broadcast(
      pubsub,
      "pyre:action:input:#{connection_id}",
      {:action, execution_id, action}
    )

    socket =
      socket
      |> assign(
        execution: %{
          id: execution_id,
          connection_id: connection_id,
          status: :running
        }
      )
      |> assign(action_output: [])

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    presences = update_presences(socket.assigns.presences, diff)
    {:noreply, assign(socket, :presences, presences)}
  end

  def handle_info({:action_output, payload}, socket) do
    line = payload["line"] || ""
    {:noreply, assign(socket, action_output: socket.assigns.action_output ++ [line])}
  end

  def handle_info({:action_complete, payload}, socket) do
    execution = socket.assigns.execution
    exit_codes = payload["exit_codes"] || []
    status = if Enum.all?(exit_codes, &(&1 == 0)), do: :complete, else: :error
    {:noreply, assign(socket, execution: %{execution | status: status})}
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

      <div :if={@execution} class="mt-8">
        <div class="flex items-center gap-3 mb-3">
          <h2 class="text-lg font-semibold">Remote Execution</h2>
          <span class="text-xs font-mono text-base-content/50">{@execution.id}</span>
          <span class={[
            "badge badge-sm",
            @execution.status == :running && "badge-info",
            @execution.status == :complete && "badge-success",
            @execution.status == :error && "badge-error"
          ]}>
            {@execution.status}
          </span>
        </div>
        <div class="font-mono text-sm bg-neutral text-neutral-content p-4 rounded-lg max-h-96 overflow-y-auto">
          <div :for={line <- @action_output} class="whitespace-pre-wrap">{line}</div>
          <div :if={@execution.status == :running} class="animate-pulse mt-1">_</div>
        </div>
      </div>
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
