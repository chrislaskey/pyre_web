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

  test "renders workflow selector with Feature Build default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pyre/runs/new")
    assert html =~ "Feature Build"
    assert html =~ "Iterative Build"
    assert html =~ "Product Manager"
    assert html =~ "Programmer"
  end

  test "switching to iterative build changes stages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pyre/runs/new")

    html = render_click(view, "select_workflow", %{"workflow" => "iterative_build"})

    assert html =~ "Software Architect"
    assert html =~ "Branch Setup"
    assert html =~ "Software Engineer"
    assert html =~ "PR Reviewer"
    refute html =~ "Programmer"
    refute html =~ "Test Writer"
  end

  test "switching back to feature build restores stages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pyre/runs/new")

    render_click(view, "select_workflow", %{"workflow" => "iterative_build"})
    html = render_click(view, "select_workflow", %{"workflow" => "feature_build"})

    assert html =~ "Programmer"
    assert html =~ "Test Writer"
    refute html =~ "Software Architect"
    refute html =~ "Software Engineer"
  end
end
