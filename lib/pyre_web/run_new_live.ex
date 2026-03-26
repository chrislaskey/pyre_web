defmodule PyreWeb.RunNewLive do
  @moduledoc """
  LiveView for submitting a new Pyre pipeline run.
  """
  use PyreWeb.Web, :live_view

  @feature_build_stages [
    {:planning, "Product Manager"},
    {:designing, "Designer"},
    {:implementing, "Programmer"},
    {:testing, "Test Writer"},
    {:reviewing, "QA Reviewer"},
    {:shipping, "Shipper"}
  ]

  @iterative_build_stages [
    {:planning, "Product Manager"},
    {:designing, "Designer"},
    {:architecting, "Software Architect"},
    {:branch_setup, "Branch Setup"},
    {:engineering, "Software Engineer"},
    {:reviewing, "PR Reviewer"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "New Run — Pyre",
        form: to_form(%{"feature_description" => "", "feature_name" => ""}, as: :run),
        feature_name: "",
        feature_suggestions: [],
        workflow: :iterative_build,
        toggleable_stages: @iterative_build_stages,
        skipped_stages: MapSet.new(),
        interactive_stages: MapSet.new(),
        llm_backend: :claude_cli
      )
      |> allow_upload(:attachments,
        accept: ~w(.txt .md .csv .json .html .css .js .png .jpg .jpeg .gif .webp),
        max_entries: 10,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"run" => params}, socket) do
    feature_name = Map.get(params, "feature_name", "")

    suggestions =
      if String.length(String.trim(feature_name)) > 0 do
        features_dir = Path.expand("priv/pyre/features", File.cwd!())

        apply(Pyre.Plugins.Artifact, :list_features, [features_dir])
        |> Enum.filter(&String.contains?(&1, String.downcase(String.trim(feature_name))))
      else
        features_dir = Path.expand("priv/pyre/features", File.cwd!())
        apply(Pyre.Plugins.Artifact, :list_features, [features_dir])
      end

    {:noreply,
     assign(socket,
       form: to_form(params, as: :run),
       feature_name: feature_name,
       feature_suggestions: suggestions
     )}
  end

  def handle_event("select_workflow", %{"workflow" => workflow_str}, socket) do
    {workflow, stages} =
      case workflow_str do
        "iterative_build" -> {:iterative_build, @iterative_build_stages}
        _ -> {:feature_build, @feature_build_stages}
      end

    socket =
      assign(socket,
        workflow: workflow,
        toggleable_stages: stages,
        skipped_stages: MapSet.new(),
        interactive_stages: MapSet.new()
      )

    {:noreply, socket}
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

  def handle_event("toggle_interactive_stage", %{"stage" => stage_str}, socket) do
    stage = String.to_existing_atom(stage_str)

    interactive =
      if MapSet.member?(socket.assigns.interactive_stages, stage) do
        MapSet.delete(socket.assigns.interactive_stages, stage)
      else
        MapSet.put(socket.assigns.interactive_stages, stage)
      end

    {:noreply, assign(socket, interactive_stages: interactive)}
  end

  def handle_event("select_backend", %{"backend" => backend}, socket) do
    llm_backend =
      case backend do
        "claude_cli" -> :claude_cli
        _ -> :req_llm
      end

    {:noreply, assign(socket, llm_backend: llm_backend)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  def handle_event("submit", %{"run" => params}, socket) do
    desc = String.trim(Map.get(params, "feature_description", ""))
    feature_name = String.trim(Map.get(params, "feature_name", ""))

    if desc == "" do
      {:noreply, put_flash(socket, :error, "Feature description cannot be empty.")}
    else
      attachments =
        consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
          content = File.read!(path)

          media_type =
            apply(Pyre.Plugins.Artifact, :media_type_from_filename, [entry.client_name])

          {:ok,
           %{
             filename: entry.client_name,
             content: content,
             media_type: media_type
           }}
        end)

      skipped = MapSet.to_list(socket.assigns.skipped_stages)
      interactive = MapSet.to_list(socket.assigns.interactive_stages)

      llm_module = llm_module_for(socket.assigns.llm_backend)

      feature = if feature_name == "", do: nil, else: feature_name

      case apply(Pyre.RunServer, :start_run, [
             desc,
             [
               workflow: socket.assigns.workflow,
               skipped_stages: skipped,
               interactive_stages: interactive,
               attachments: attachments,
               llm: llm_module,
               feature: feature
             ]
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

          <div id="attachment-upload" phx-hook="PasteUpload" class="mt-3">
            <.live_file_input upload={@uploads.attachments} class="hidden" />

            <div
              :for={entry <- @uploads.attachments.entries}
              class="flex items-center gap-3 p-3 border border-base-300 rounded-lg bg-base-200/50 mb-2"
            >
              <.live_img_preview
                :if={String.starts_with?(entry.client_type, "image/")}
                entry={entry}
                class="max-h-24 rounded border border-base-300"
              />
              <div
                :if={not String.starts_with?(entry.client_type, "image/")}
                class="flex items-center justify-center w-10 h-10 rounded border border-base-300 bg-base-200 text-base-content/40 text-xs font-mono shrink-0"
              >
                {entry.client_name |> Path.extname() |> String.trim_leading(".")}
              </div>
              <div class="flex flex-col gap-1">
                <span class="text-sm text-base-content/70">{entry.client_name}</span>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="btn btn-ghost btn-xs w-fit"
                >
                  Remove
                </button>
              </div>
              <p
                :for={err <- upload_errors(@uploads.attachments, entry)}
                class="text-error text-sm"
              >
                {upload_error_to_string(err)}
              </p>
            </div>

            <div
              phx-drop-target={@uploads.attachments.ref}
              class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center text-sm text-base-content/50"
            >
              Paste or drop a file, or
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
            <span class="label-text font-medium">Feature Name</span>
            <span class="label-text-alt text-base-content/50">Optional</span>
          </label>
          <input
            type="text"
            name="run[feature_name]"
            value={@feature_name}
            list="feature-suggestions"
            placeholder="e.g. products-page"
            class="input input-bordered w-full font-mono text-sm"
          />
          <datalist id="feature-suggestions">
            <option :for={name <- @feature_suggestions} value={name} />
          </datalist>
          <p class="text-sm text-base-content/50 mt-1">
            Group related runs under a feature name. Leave empty for a standalone run.
          </p>
        </div>

        <div class="mb-4">
          <label class="label mb-1">
            <span class="label-text font-medium">Workflow</span>
          </label>
          <div class="flex gap-4">
            <label class="label cursor-pointer justify-start gap-2">
              <input
                type="radio"
                name="workflow"
                value="feature_build"
                checked={@workflow == :feature_build}
                phx-click="select_workflow"
                phx-value-workflow="feature_build"
                class="radio radio-sm radio-primary"
              />
              <span class="label-text">Feature Build</span>
            </label>
            <label class="label cursor-pointer justify-start gap-2">
              <input
                type="radio"
                name="workflow"
                value="iterative_build"
                checked={@workflow == :iterative_build}
                phx-click="select_workflow"
                phx-value-workflow="iterative_build"
                class="radio radio-sm radio-primary"
              />
              <span class="label-text">Iterative Build</span>
            </label>
          </div>
        </div>

        <div class="mb-4">
          <label class="label mb-1">
            <span class="label-text font-medium">LLM Backend</span>
          </label>
          <div class="flex gap-4">
            <label class="label cursor-pointer justify-start gap-2">
              <input
                type="radio"
                name="llm_backend"
                value="req_llm"
                checked={@llm_backend == :req_llm}
                phx-click="select_backend"
                phx-value-backend="req_llm"
                class="radio radio-sm radio-primary"
              />
              <span class="label-text">API (ReqLLM)</span>
            </label>
            <label class="label cursor-pointer justify-start gap-2">
              <input
                type="radio"
                name="llm_backend"
                value="claude_cli"
                checked={@llm_backend == :claude_cli}
                phx-click="select_backend"
                phx-value-backend="claude_cli"
                class="radio radio-sm radio-primary"
              />
              <span class="label-text">Claude CLI</span>
            </label>
          </div>
          <p class="text-sm text-base-content/50 mt-1">
            API uses ReqLLM with per-token billing. Claude CLI uses the local <code>claude</code> command (free with Pro/Max subscription).
          </p>
        </div>

        <div class="mb-4">
          <label class="label mb-1">
            <span class="label-text font-medium">Workflow Stages</span>
          </label>
          <p class="text-sm text-base-content/50 mb-2">
            Uncheck stages to skip them. Enable interactive to pause after each stage for feedback.
          </p>
          <div class="flex flex-col gap-2">
            <div
              :for={{stage_key, label} <- @toggleable_stages}
              class="flex items-center gap-3"
            >
              <input
                type="checkbox"
                checked={stage_key not in @skipped_stages}
                phx-click="toggle_stage"
                phx-value-stage={stage_key}
                class="toggle toggle-sm toggle-primary"
              />
              <span class="text-sm flex-1">{label}</span>
              <label class="flex items-center gap-1 cursor-pointer">
                <span class="text-xs text-base-content/40">interactive</span>
                <input
                  type="checkbox"
                  checked={stage_key in @interactive_stages}
                  phx-click="toggle_interactive_stage"
                  phx-value-stage={stage_key}
                  class="toggle toggle-xs toggle-accent"
                />
              </label>
            </div>
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

  defp llm_module_for(:claude_cli), do: Pyre.LLM.ClaudeCLI
  defp llm_module_for(_), do: Pyre.LLM.ReqLLM

  defp upload_error_to_string(:too_large), do: "File too large (max 10 MB)"
  defp upload_error_to_string(:not_accepted), do: "Invalid file type"
  defp upload_error_to_string(:too_many_files), do: "Too many files (max 10)"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
