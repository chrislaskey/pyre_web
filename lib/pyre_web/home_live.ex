defmodule PyreWeb.HomeLive do
  @moduledoc """
  Landing page for the PyreWeb interface.
  """
  use PyreWeb.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Pyre")}
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
    </div>
    """
  end

  defp pyre_version do
    case Application.spec(:pyre, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
  end
end
