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
end
