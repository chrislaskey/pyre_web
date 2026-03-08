defmodule PyreWeb.RunNewLive do
  @moduledoc """
  LiveView for submitting a new Pyre pipeline run.
  """
  use PyreWeb.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "New Run — Pyre",
        form: to_form(%{"feature_description" => ""}, as: :run)
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("submit", %{"run" => %{"feature_description" => desc}}, socket) do
    desc = String.trim(desc)

    if desc == "" do
      {:noreply, put_flash(socket, :error, "Feature description cannot be empty.")}
    else
      case apply(Pyre.RunServer, :start_run, [desc]) do
        {:ok, run_id} ->
          {:noreply, push_navigate(socket, to: pyre_path(socket, "/runs/#{run_id}"))}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to start run: #{inspect(reason)}")}
      end
    end
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
        <h1 class="text-xl font-bold">New Run</h1>
      </div>

      <.flash_group flash={@flash} />

      <form phx-submit="submit" class="mb-6">
        <div class="mb-4">
          <label class="label mb-1">
            <span class="label-text font-medium">Feature Description</span>
          </label>
          <textarea
            name="run[feature_description]"
            class="textarea textarea-bordered w-full h-32 font-mono text-sm"
            placeholder="Build a products listing page with search and pagination..."
          >{Phoenix.HTML.Form.input_value(@form, :feature_description)}</textarea>
        </div>

        <button type="submit" class="btn btn-primary">
          Run Pipeline
        </button>
      </form>
    </div>
    """
  end

  defp flash_group(assigns) do
    ~H"""
    <div :if={msg = Phoenix.Flash.get(@flash, :error)} class="alert alert-error mb-4">
      <span>{msg}</span>
    </div>
    <div :if={msg = Phoenix.Flash.get(@flash, :info)} class="alert alert-info mb-4">
      <span>{msg}</span>
    </div>
    """
  end
end
