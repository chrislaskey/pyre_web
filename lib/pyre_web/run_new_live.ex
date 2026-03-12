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
      socket
      |> assign(
        page_title: "New Run — Pyre",
        form: to_form(%{"feature_description" => ""}, as: :run),
        toggleable_stages: @toggleable_stages,
        skipped_stages: MapSet.new()
      )
      |> allow_upload(:attachments,
        accept:
          ~w(.txt .md .csv .json .ex .exs .html .css .js .ts .png .jpg .jpeg .gif .webp),
        max_entries: 10,
        max_file_size: 10_000_000
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

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  def handle_event("submit", %{"run" => %{"feature_description" => desc}}, socket) do
    desc = String.trim(desc)

    if desc == "" do
      {:noreply, put_flash(socket, :error, "Feature description cannot be empty.")}
    else
      attachments =
        consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
          content = File.read!(path)
          media_type = apply(Pyre.Plugins.Artifact, :media_type_from_filename, [entry.client_name])

          {:ok,
           %{
             filename: entry.client_name,
             content: content,
             media_type: media_type
           }}
        end)

      skipped = MapSet.to_list(socket.assigns.skipped_stages)

      case apply(Pyre.RunServer, :start_run, [
             desc,
             [skipped_stages: skipped, attachments: attachments]
           ]) do
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
            <span class="label-text font-medium">Attachments</span>
          </label>
          <p class="text-sm text-base-content/50 mb-2">
            Attach mockups, specs, or data files. All agents will see these.
          </p>

          <div id="attachment-upload" phx-hook=".PasteUpload">
            <.live_file_input upload={@uploads.attachments} class="hidden" />

            <div :if={@uploads.attachments.entries != []} class="flex flex-col gap-2 mb-2">
              <div
                :for={entry <- @uploads.attachments.entries}
                class="flex items-center gap-3 p-2 border border-base-300 rounded-lg bg-base-200/50"
              >
                <.live_img_preview
                  :if={String.starts_with?(entry.client_type, "image/")}
                  entry={entry}
                  class="max-h-12 rounded border border-base-300"
                />
                <span
                  :if={not String.starts_with?(entry.client_type, "image/")}
                  class="text-base-content/30 text-lg leading-none"
                >
                  &#128196;
                </span>
                <div class="flex-1 min-w-0">
                  <span class="text-sm font-mono truncate block">{entry.client_name}</span>
                  <span class="text-xs text-base-content/50">{format_file_size(entry.client_size)}</span>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="btn btn-ghost btn-xs"
                >
                  Remove
                </button>
                <p
                  :for={err <- upload_errors(@uploads.attachments, entry)}
                  class="text-error text-xs"
                >
                  {upload_error_to_string(err)}
                </p>
              </div>
            </div>

            <div
              :if={length(@uploads.attachments.entries) < 10}
              phx-drop-target={@uploads.attachments.ref}
              class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center text-sm text-base-content/50"
            >
              Paste or drop files, or
              <label class="link cursor-pointer" for={@uploads.attachments.ref}>
                browse
              </label>
            </div>

            <p
              :for={err <- upload_errors(@uploads.attachments)}
              class="text-error text-sm mt-1"
            >
              {upload_error_to_string(err)}
            </p>
          </div>
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

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PasteUpload">
      export default {
        mounted() {
          this.handlePaste = (e) => {
            const files = e.clipboardData?.files;
            if (!files?.length) return;

            const input = this.el.querySelector("input[type=file]");
            if (!input) return;

            // Don't paste if drop zone is gone (max 10 files reached)
            if (!this.el.querySelector("[phx-drop-target]")) return;

            const dt = new DataTransfer();
            for (const f of files) {
              if (f.type.startsWith("image/")) dt.items.add(f);
            }
            if (dt.files.length) {
              input.files = dt.files;
              input.dispatchEvent(new Event("input", { bubbles: true }));
            }
          };
          window.addEventListener("paste", this.handlePaste);
        },
        destroyed() {
          window.removeEventListener("paste", this.handlePaste);
        }
      }
    </script>
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

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_file_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp upload_error_to_string(:too_large), do: "File is too large (max 10 MB)"
  defp upload_error_to_string(:too_many_files), do: "Too many files (max 10)"
  defp upload_error_to_string(:not_accepted), do: "File type not accepted"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
