defmodule PyreWeb.RunListLive do
  @moduledoc """
  LiveView listing all Pyre pipeline runs.
  """
  use PyreWeb.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      if pubsub = Application.get_env(:pyre, :pubsub) do
        Phoenix.PubSub.subscribe(pubsub, "pyre:runs")
      end
    end

    runs = apply(Pyre.RunServer, :list_runs, [])

    socket =
      assign(socket,
        page_title: "Runs — Pyre",
        runs: runs
      )

    {:ok, socket}
  end

  @impl true
  def handle_info({:pyre_run_status, _id, _status}, socket) do
    runs = apply(Pyre.RunServer, :list_runs, [])
    {:noreply, assign(socket, runs: runs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-8 max-w-4xl mx-auto px-4">
      <div class="mb-6 flex items-center gap-4">
        <.link
          navigate={pyre_path(@socket, "")}
          class="text-sm text-base-content/50 hover:text-base-content"
        >
          &larr; Home
        </.link>
        <h1 class="text-xl font-bold">Runs</h1>
        <.link navigate={pyre_path(@socket, "/runs/new")} class="btn btn-primary btn-sm ml-auto">
          New Run
        </.link>
      </div>

      <%= if @runs == [] do %>
        <p class="text-base-content/50">No runs yet.</p>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>ID</th>
                <th>Status</th>
                <th>Description</th>
                <th>Started</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={run <- @runs}>
                <td>
                  <.link
                    navigate={pyre_path(@socket, "/runs/#{run.id}")}
                    class="link link-primary font-mono text-sm"
                  >
                    {run.id}
                  </.link>
                </td>
                <td>
                  <span class={"badge badge-sm #{status_badge_class(run.status)}"}>
                    {status_label(run.status)}
                  </span>
                </td>
                <td class="max-w-md truncate">{truncate(run.feature_description, 80)}</td>
                <td class="text-sm text-base-content/70">{format_time(run.started_at)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
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
  defp status_label(_), do: "Unknown"

  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max) <> "..."

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_time(_), do: ""
end
