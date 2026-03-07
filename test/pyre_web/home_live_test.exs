defmodule PyreWeb.HomeLiveTest do
  use PyreWeb.Test.ConnCase, async: true

  test "renders the home page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pyre")
    assert html =~ "Pyre"
    assert html =~ "Multi-agent LLM framework"
  end

  test "displays pyre version", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pyre")

    version =
      case Application.spec(:pyre, :vsn) do
        nil -> "unknown"
        vsn -> to_string(vsn)
      end

    assert html =~ version
  end
end
