defmodule PyreWeb.RunNewLive do
  @moduledoc """
  LiveView for submitting a new Pyre pipeline run.
  """
  use PyreWeb.Web, :live_view

  @overnight_feature_stages [
    {:planning, "Product Manager"},
    {:designing, "Designer"},
    {:implementing, "Programmer"},
    {:testing, "Test Writer"},
    {:reviewing, "QA Reviewer"},
    {:shipping, "Shipper"}
  ]

  @feature_stages [
    {:architecting, "Software Architect"},
    {:pr_setup, "PR Setup"},
    {:engineering, "Software Engineer"}
  ]

  @prototype_stages [{:prototyping, "Prototype Engineer"}]

  @task_stages [{:tasking, "Generalist"}]

  @code_review_stages [{:reviewing, "PR Reviewer"}]

  @chat_stages [{:generalist, "Generalist"}]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "New Run — Pyre",
        form: to_form(%{"feature_description" => "", "feature_name" => ""}, as: :run),
        feature_name: "",
        feature_suggestions: [],
        workflow: :chat,
        toggleable_stages: @chat_stages,
        skipped_stages: MapSet.new(),
        interactive_stages: MapSet.new([:generalist]),
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
    {workflow, stages, interactive} =
      case workflow_str do
        "chat" -> {:chat, @chat_stages, MapSet.new([:generalist])}
        "feature" -> {:feature, @feature_stages, MapSet.new()}
        "prototype" -> {:prototype, @prototype_stages, MapSet.new([:prototyping])}
        "task" -> {:task, @task_stages, MapSet.new()}
        "code_review" -> {:code_review, @code_review_stages, MapSet.new()}
        "overnight_feature" -> {:overnight_feature, @overnight_feature_stages, MapSet.new()}
      end

    socket =
      assign(socket,
        workflow: workflow,
        toggleable_stages: stages,
        skipped_stages: MapSet.new(),
        interactive_stages: interactive
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
