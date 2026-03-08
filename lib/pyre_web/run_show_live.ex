defmodule PyreWeb.RunShowLive do
  @moduledoc """
  LiveView for streaming output of a Pyre pipeline run.

  On mount, subscribes to PubSub for real-time updates, then fetches
  buffered state from the RunServer to catch up on any events that
  occurred before the subscription.
  """
  use PyreWeb.Web, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      if pubsub = Application.get_env(:pyre, :pubsub) do
        Phoenix.PubSub.subscribe(pubsub, "pyre:runs:#{id}")
      end
    end

    case apply(Pyre.RunServer, :get_state, [id]) do
      {:ok, run_state} ->
        socket =
          socket
          |> assign(
            page_title: "Run #{id} — Pyre",
            run_id: id,
            status: run_state.status,
            phase: run_state.phase,
            feature_description: run_state.feature_description
          )
          |> stream(:items, run_state.log)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, redirect(socket, to: pyre_path(socket, "/runs"))}
    end
  end

  @impl true
  def handle_info({:pyre_run_event, _id, entry}, socket) do
    {:noreply, stream_insert(socket, :items, entry)}
  end

  def handle_info({:pyre_run_status, _id, status}, socket) do
    {:noreply, assign(socket, status: status)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-8 max-w-4xl mx-auto px-4">
      <div class="mb-6 flex items-center gap-4">
        <.link
          navigate={pyre_path(@socket, "/runs")}
          class="text-sm text-base-content/50 hover:text-base-content"
        >
          &larr; Runs
        </.link>
        <h1 class="text-xl font-bold">Run {@run_id}</h1>
      </div>

      <div class="mb-4 text-sm text-base-content/70">
        {@feature_description}
      </div>

      <div class="border border-base-300 rounded-lg overflow-hidden">
        <div class="bg-base-200 px-4 py-2 flex items-center justify-between border-b border-base-300">
          <span class="text-sm font-medium">Output</span>
          <span class={"badge badge-sm #{status_badge_class(@status)}"}>
            {status_label(@status)}
          </span>
        </div>

        <div
          id="output-stream"
          phx-update="stream"
          class="font-mono text-sm p-4 space-y-1 max-h-[600px] overflow-y-auto bg-neutral text-neutral-content"
        >
          <div
            :for={{dom_id, item} <- @streams.items}
            id={dom_id}
            class={item_class(item.type)}
          >
            <pre class="whitespace-pre-wrap m-0">{item.content}</pre>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge_class(:running), do: "badge-warning"
  defp status_badge_class(:complete), do: "badge-success"
  defp status_badge_class(:error), do: "badge-error"
  defp status_badge_class(_), do: "badge-neutral"

  defp status_label(:running), do: "Running"
  defp status_label(:complete), do: "Complete"
  defp status_label(:error), do: "Error"
  defp status_label(_), do: ""

  defp item_class(:log), do: "text-info"
  defp item_class(:output), do: "text-neutral-content"
  defp item_class(:error), do: "text-error"
  defp item_class(_), do: ""
end
