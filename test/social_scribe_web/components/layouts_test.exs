defmodule SocialScribeWeb.Components.LayoutsTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "layout_names/0 returns all layout names" do
    assert SocialScribeWeb.Layouts.layout_names() == [:root, :app, :dashboard]
  end

  test "root and app layout render when visiting landing page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "SocialScribe"
    assert html =~ "Turn meetings into"
  end

  describe "explicit layout rendering (coverage)" do
    test "root/1 renders with conn and inner_content", %{conn: conn} do
      conn = get(conn, ~p"/")
      assigns = %{conn: conn, inner_content: "<div>inner</div>"}
      html = render_component(&SocialScribeWeb.Layouts.root/1, assigns)
      assert html =~ "SocialScribe"
      assert html =~ "inner"
      assert html =~ "csrf-token"
    end

    test "app/1 renders with flash and inner_content", %{conn: conn} do
      conn = get(conn, ~p"/")
      assigns = %{
        conn: conn,
        flash: %{},
        inner_content: "<div>app inner</div>"
      }
      html = render_component(&SocialScribeWeb.Layouts.app/1, assigns)
      assert html =~ "SocialScribe"
      assert html =~ "app inner"
    end
  end

  describe "dashboard layout" do
    setup :register_and_log_in_user

    test "renders when visiting dashboard settings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")
      assert html =~ "SocialScribe"
      assert html =~ "Account"
    end

    test "dashboard/1 renders with current_user, current_path, flash, inner_content", %{
      conn: conn
    } do
      conn = get(conn, ~p"/dashboard/settings")
      assigns =
        Map.merge(conn.assigns, %{
          inner_content: "<div>dashboard inner</div>"
        })

      html = render_component(&SocialScribeWeb.Layouts.dashboard/1, assigns)
      assert html =~ "SocialScribe"
      assert html =~ "Account"
      assert html =~ "dashboard inner"
    end
  end
end
