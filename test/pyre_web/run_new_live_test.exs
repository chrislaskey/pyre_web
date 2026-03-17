defmodule PyreWeb.RunNewLiveTest do
  use PyreWeb.Test.ConnCase, async: true

  test "renders the new run form", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pyre/runs/new")
    assert html =~ "New Run"
    assert html =~ "Feature Description"
    assert html =~ "Run Pipeline"
  end

  test "back link points to prefixed home path", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pyre/runs/new")
    assert html =~ ~s|href="/pyre"|
    assert html =~ "Home"
  end

  test "empty submit shows error flash", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pyre/runs/new")

    html =
      view
      |> element("form")
      |> render_submit(%{"run" => %{"feature_description" => ""}})

    assert html =~ "cannot be empty"
  end

  test "renders workflow selector with Iterative Build default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pyre/runs/new")
    assert html =~ "Feature Build"
    assert html =~ "Iterative Build"
    assert html =~ "Product Manager"
    assert html =~ "Software Architect"
  end

  test "switching to feature build changes stages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pyre/runs/new")

    html = render_click(view, "select_workflow", %{"workflow" => "feature_build"})

    assert html =~ "Programmer"
    assert html =~ "Test Writer"
    refute html =~ "Software Architect"
    refute html =~ "Software Engineer"
  end

  test "renders LLM backend selector with API default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pyre/runs/new")
    assert html =~ "LLM Backend"
    assert html =~ "API (ReqLLM)"
    assert html =~ "Claude CLI"
  end

  test "switching to Claude CLI backend", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pyre/runs/new")

    html = render_click(view, "select_backend", %{"backend" => "claude_cli"})

    assert html =~ "Claude CLI"
    assert html =~ ~s|value="claude_cli"|
  end

  test "switching back to iterative build restores stages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pyre/runs/new")

    render_click(view, "select_workflow", %{"workflow" => "feature_build"})
    html = render_click(view, "select_workflow", %{"workflow" => "iterative_build"})

    assert html =~ "Software Architect"
    assert html =~ "Software Engineer"
    refute html =~ "Programmer"
    refute html =~ "Test Writer"
  end
end
