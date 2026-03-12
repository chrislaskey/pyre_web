defmodule PyreWeb.RunNewLive do
  @moduledoc """
  LiveView for submitting a new Pyre pipeline run.
  """
  use PyreWeb.Web, :live_view

  @toggleable_stages [
    {:planning, "Product Manager"},
    {:designing, "Designer"},
    {:implementing, "Programmer"},
    {:testing, "Test Writer"},
    {:reviewing, "QA Reviewer"},
    {:shipping, "Shipper"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "New Run — Pyre",
        form: to_form(%{"feature_description" => ""}, as: :run),
        toggleable_stages: @toggleable_stages,
        skipped_stages: MapSet.new()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"run" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :run))}
  end

  def handle_event("toggle_stage", %{"stage" => stage_str}, socket) do
    stage = String.to_existing_atom(stage_str)

    skipped =
      if MapSet.member?(socket.assigns.skipped_stages, stage) do
        MapSet.delete(socket.assigns.skipped_stages, stage)
      else
        MapSet.put(socket.assigns.skipped_stages, stage)
      end

    {:noreply, assign(socket, skipped_stages: skipped)}
  end

  def handle_event("submit", %{"run" => %{"feature_description" => desc}}, socket) do
    desc = String.trim(desc)

    if desc == "" do
      {:noreply, put_flash(socket, :error, "Feature description cannot be empty.")}
    else
      skipped = MapSet.to_list(socket.assigns.skipped_stages)

      case apply(Pyre.RunServer, :start_run, [desc, [skipped_stages: skipped]]) do
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

      <form phx-submit="submit" phx-change="validate" class="mb-6">
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

        <div class="mb-4">
          <label class="label mb-1">
            <span class="label-text font-medium">Workflow Stages</span>
          </label>
          <p class="text-sm text-base-content/50 mb-2">
            Uncheck stages to skip them. Skipped stages use general best practices as fallback.
          </p>
          <div class="flex flex-col gap-2">
            <label
              :for={{stage_key, label} <- @toggleable_stages}
              class="label cursor-pointer justify-start gap-2"
            >
              <input
                type="checkbox"
                checked={stage_key not in @skipped_stages}
                phx-click="toggle_stage"
                phx-value-stage={stage_key}
                class="checkbox checkbox-sm"
              />
              <span class="label-text">{label}</span>
            </label>
          </div>
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
