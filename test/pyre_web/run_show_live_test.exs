defmodule PyreWeb.RunShowLiveTest do
  use PyreWeb.Test.ConnCase, async: false

  alias PyreWeb.Test.AgentMock

  setup do
    on_exit(fn -> AgentMock.teardown() end)
    :ok
  end

  test "shows run output page with buffered entries", %{conn: conn} do
    AgentMock.setup(["Req.", "Design.", "Impl.", "Tests.", "APPROVE\n\nGood."])

    tmp_dir = Path.join(System.tmp_dir!(), "pyre_show_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp_dir, "priv/pyre/runs"))

    {:ok, id} =
      Pyre.RunServer.start_run("Build a test page",
        llm: AgentMock,
        streaming: false,
        project_dir: tmp_dir
      )

    wait_for_status(id, :complete)

    {:ok, _view, html} = live(conn, "/pyre/runs/#{id}")
    assert html =~ id
    assert html =~ "output-stream"
    assert html =~ "Complete"

    File.rm_rf!(tmp_dir)
  end

  test "redirects to /runs for unknown run ID", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/pyre/runs"}}} =
             live(conn, "/pyre/runs/deadbeef")
  end

  test "handles PubSub events for stream updates", %{conn: conn} do
    AgentMock.setup(["Req.", "Design.", "Impl.", "Tests.", "APPROVE\n\nGood."])

    tmp_dir =
      Path.join(System.tmp_dir!(), "pyre_show_pubsub_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(tmp_dir, "priv/pyre/runs"))

    {:ok, id} =
      Pyre.RunServer.start_run("Build a test page",
        llm: AgentMock,
        streaming: false,
        project_dir: tmp_dir
      )

    {:ok, view, _html} = live(conn, "/pyre/runs/#{id}")

    # Send a PubSub event directly to the LiveView
    entry = %{
      id: "test-entry-1",
      type: :log,
      content: "Custom test message",
      timestamp: DateTime.utc_now()
    }

    send(view.pid, {:pyre_run_event, id, entry})
    html = render(view)
    assert html =~ "Custom test message"

    # Send a status update
    send(view.pid, {:pyre_run_status, id, :complete})
    html = render(view)
    assert html =~ "Complete"

    wait_for_status(id, :complete)
    File.rm_rf!(tmp_dir)
  end

  test "shows feature description", %{conn: conn} do
    AgentMock.setup(["Req.", "Design.", "Impl.", "Tests.", "APPROVE\n\nGood."])

    tmp_dir =
      Path.join(System.tmp_dir!(), "pyre_show_desc_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(tmp_dir, "priv/pyre/runs"))

    {:ok, id} =
      Pyre.RunServer.start_run("Build a products listing page",
        llm: AgentMock,
        streaming: false,
        project_dir: tmp_dir
      )

    {:ok, _view, html} = live(conn, "/pyre/runs/#{id}")
    assert html =~ "Build a products listing page"

    wait_for_status(id, :complete)
    File.rm_rf!(tmp_dir)
  end

  test "back link points to runs list", %{conn: conn} do
    AgentMock.setup(["Req.", "Design.", "Impl.", "Tests.", "APPROVE\n\nGood."])

    tmp_dir =
      Path.join(System.tmp_dir!(), "pyre_show_back_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(tmp_dir, "priv/pyre/runs"))

    {:ok, id} =
      Pyre.RunServer.start_run("Test", llm: AgentMock, streaming: false, project_dir: tmp_dir)

    {:ok, _view, html} = live(conn, "/pyre/runs/#{id}")
    assert html =~ ~s|href="/pyre/runs"|
    assert html =~ "Runs"

    wait_for_status(id, :complete)
    File.rm_rf!(tmp_dir)
  end

  defp wait_for_status(id, expected_status, timeout \\ 15_000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      case Pyre.RunServer.get_state(id) do
        {:ok, %{status: ^expected_status}} ->
          :done

        {:ok, _} ->
          if System.monotonic_time(:millisecond) > deadline do
            flunk("Timed out waiting for status #{expected_status}")
          end

          Process.sleep(50)
          :continue

        {:error, :not_found} ->
          flunk("Run #{id} not found")
      end
    end)
    |> Enum.find(&(&1 == :done))
  end
end
