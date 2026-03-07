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
    <div class="py-8 max-w-6xl mx-auto">
      <h1 class="mb-3 text-xl font-bold">Pyre</h1>
      <p class="text-gray-800">Multi-agent LLM framework for Phoenix development.</p>
      <p class="text-gray-600 text-sm">Pyre v{pyre_version()}</p>
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
