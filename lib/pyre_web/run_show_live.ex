defmodule PyreWeb.RunShowLive do
  @moduledoc """
  LiveView for streaming output of a Pyre pipeline run.

  On mount, subscribes to PubSub for real-time updates, then fetches
  buffered state from the RunServer to catch up on any events that
  occurred before the subscription.
  """
  use PyreWeb.Web, :live_view

  @feature_build_phases [
    {:planning, "Planning"},
    {:designing, "Design"},
    {:implementing, "Implementation"},
    {:testing, "Testing"},
    {:reviewing, "Review"},
    {:shipping, "Shipping"}
  ]

  @feature_build_order [:planning, :designing, :implementing, :testing, :reviewing, :shipping]

  @iterative_build_phases [
    {:planning, "Planning"},
    {:designing, "Design"},
    {:architecting, "Architecture"},
    {:branch_setup, "Branch Setup"},
    {:engineering, "Engineering"},
    {:reviewing, "Review"}
  ]

  @iterative_build_order [
    :planning,
    :designing,
    :architecting,
    :branch_setup,
    :engineering,
    :reviewing
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      if pubsub = Application.get_env(:pyre, :pubsub) do
        Phoenix.PubSub.subscribe(pubsub, "pyre:runs:#{id}")
      end
    end

    case apply(Pyre.RunServer, :get_state, [id]) do
      {:ok, run_state} ->
        workflow = Map.get(run_state, :workflow, :feature_build)

        {phases, phase_order} =
          case workflow do
            :iterative_build -> {@iterative_build_phases, @iterative_build_order}
            _ -> {@feature_build_phases, @feature_build_order}
          end

        socket =
          socket
          |> assign(
            page_title: "Run #{id} — Pyre",
            run_id: id,
            status: run_state.status,
            phase: run_state.phase,
            feature: Map.get(run_state, :feature),
            feature_description: run_state.feature_description,
            skipped_stages: run_state.skipped_stages,
            phases: phases,
            phase_order: phase_order,
            confirm_stop: false
          )
          |> stream(:items, run_state.log)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, redirect(socket, to: pyre_path(socket, "/runs"))}
    end
  end

  @impl true
  def handle_event("toggle_stage", %{"stage" => stage_str}, socket) do
    stage = String.to_existing_atom(stage_str)

    case apply(Pyre.RunServer, :toggle_stage, [socket.assigns.run_id, stage]) do
      :ok -> {:noreply, socket}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("request_stop", _params, socket) do
    {:noreply, assign(socket, confirm_stop: true)}
  end

  def handle_event("cancel_stop", _params, socket) do
    {:noreply, assign(socket, confirm_stop: false)}
  end

  def handle_event("confirm_stop", _params, socket) do
    apply(Pyre.RunServer, :stop_run, [socket.assigns.run_id])
    {:noreply, assign(socket, confirm_stop: false)}
  end

  @impl true
  def handle_info({:pyre_run_event, _id, entry}, socket) do
    {:noreply, stream_insert(socket, :items, entry)}
  end

  def handle_info({:pyre_run_status, _id, status}, socket) do
    {:noreply, assign(socket, status: status)}
  end

  def handle_info({:pyre_run_phase, _id, phase}, socket) do
    {:noreply, assign(socket, phase: phase)}
  end

  def handle_info({:pyre_run_skipped_stages, _id, skipped}, socket) do
    {:noreply, assign(socket, skipped_stages: skipped)}
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
        <span class={"badge badge-sm #{status_badge_class(@status)}"}>
          {status_label(@status)}
        </span>
        <%= if @status == :running do %>
          <%= if @confirm_stop do %>
            <span class="ml-auto flex items-center gap-2">
              <span class="text-sm text-warning">Stop this run?</span>
              <button phx-click="confirm_stop" class="btn btn-error btn-xs">Yes, stop</button>
              <button phx-click="cancel_stop" class="btn btn-ghost btn-xs">Cancel</button>
            </span>
          <% else %>
            <button phx-click="request_stop" class="btn btn-outline btn-error btn-sm ml-auto">
              Stop
            </button>
          <% end %>
        <% end %>
      </div>

      <div :if={@feature} class="mb-2 text-sm text-base-content/50 font-mono">
        Feature: {@feature}
      </div>

      <div class="mb-4 text-sm text-base-content/70">
        {@feature_description}
      </div>

      <.workflow_panel
        phases={@phases}
        phase_order={@phase_order}
        current={@phase}
        status={@status}
        skipped={@skipped_stages}
      />

      <div class="border border-base-300 rounded-lg overflow-hidden">
        <div class="bg-base-200 px-4 py-2 flex items-center justify-between border-b border-base-300">
          <span class="text-sm font-medium">Output</span>
        </div>

        <div
          id="output-stream"
          phx-update="stream"
          class="font-mono text-sm p-4 max-h-[600px] overflow-y-auto bg-neutral text-neutral-content whitespace-pre-wrap"
        >
          <pre :for={{dom_id, item} <- @streams.items} id={dom_id} class={item_class(item.type)}>{item.content}</pre>
        </div>
      </div>
    </div>
    """
  end

  defp workflow_panel(assigns) do
    ~H"""
    <div class="mb-6 border border-base-300 rounded-lg overflow-hidden">
      <div class="bg-base-200 px-4 py-2 border-b border-base-300">
        <span class="text-sm font-medium">Workflow</span>
      </div>
      <div class="p-3 flex flex-wrap gap-x-6 gap-y-2">
        <.stage_row
          :for={{phase_key, label} <- @phases}
          phase_key={phase_key}
          label={label}
          current={@current}
          status={@status}
          skipped={@skipped}
          phase_order={@phase_order}
        />
      </div>
    </div>
    """
  end

  defp stage_row(assigns) do
    assigns =
      assign(
        assigns,
        :stage_status,
        stage_status(
          assigns.phase_key,
          assigns.current,
          assigns.status,
          assigns.skipped,
          assigns.phase_order
        )
      )

    ~H"""
    <div class="flex items-center gap-2">
      <%= if toggleable?(@phase_key, @current, @status, @phase_order) do %>
        <input
          type="checkbox"
          class="toggle toggle-sm toggle-primary"
          checked={@phase_key not in @skipped}
          phx-click="toggle_stage"
          phx-value-stage={@phase_key}
        />
      <% else %>
        <input
          type="checkbox"
          class="toggle toggle-sm"
          checked={@phase_key not in @skipped}
          disabled
        />
      <% end %>
      <span class={"text-sm #{stage_label_class(@stage_status)}"}>
        {@label}
      </span>
      <.stage_badge status={@stage_status} />
    </div>
    """
  end

  defp stage_status(phase_key, current, run_status, skipped, phase_order) do
    current_idx = Enum.find_index(phase_order, &(&1 == current)) || 0
    phase_idx = Enum.find_index(phase_order, &(&1 == phase_key)) || 0

    cond do
      phase_key in skipped && phase_idx < current_idx -> :skipped
      phase_key in skipped -> :will_skip
      run_status in [:complete, :stopped] -> :done
      run_status == :error && phase_key == current -> :error
      phase_idx < current_idx -> :done
      phase_key == current -> :active
      true -> :pending
    end
  end

  defp stage_label_class(:active), do: "font-medium"
  defp stage_label_class(:done), do: "text-base-content/50"
  defp stage_label_class(:skipped), do: "text-base-content/30 line-through"
  defp stage_label_class(:will_skip), do: "text-base-content/30 line-through"
  defp stage_label_class(:error), do: "text-error font-medium"
  defp stage_label_class(_), do: "text-base-content/70"

  defp stage_badge(%{status: :active} = assigns) do
    ~H"""
    <span class="badge badge-xs badge-primary">running</span>
    """
  end

  defp stage_badge(%{status: :done} = assigns) do
    ~H"""
    <span class="badge badge-xs badge-success">done</span>
    """
  end

  defp stage_badge(%{status: :skipped} = assigns) do
    ~H"""
    <span class="badge badge-xs badge-ghost">skipped</span>
    """
  end

  defp stage_badge(%{status: :error} = assigns) do
    ~H"""
    <span class="badge badge-xs badge-error">error</span>
    """
  end

  defp stage_badge(assigns) do
    ~H"""
    """
  end

  defp toggleable?(phase_key, current, status, phase_order) do
    if status != :running do
      false
    else
      current_idx = Enum.find_index(phase_order, &(&1 == current)) || 0
      phase_idx = Enum.find_index(phase_order, &(&1 == phase_key)) || 0
      phase_idx > current_idx
    end
  end

  defp status_badge_class(:running), do: "badge-warning"
  defp status_badge_class(:complete), do: "badge-success"
  defp status_badge_class(:stopped), do: "badge-neutral"
  defp status_badge_class(:error), do: "badge-error"
  defp status_badge_class(_), do: "badge-neutral"

  defp status_label(:running), do: "Running"
  defp status_label(:complete), do: "Complete"
  defp status_label(:stopped), do: "Stopped"
  defp status_label(:error), do: "Error"
  defp status_label(_), do: ""

  defp item_class(:log), do: "block mt-1 text-info"
  defp item_class(:error), do: "block mt-1 text-error"
  defp item_class(_), do: ""
end
