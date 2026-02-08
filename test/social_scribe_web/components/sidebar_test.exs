defmodule SocialScribeWeb.Components.SidebarTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  use SocialScribeWeb, :html

  alias SocialScribeWeb.Layout.Sidebar

  defmodule SidebarLinkTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.Layout.Sidebar

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:href, session["href"] || "/")
       |> Phoenix.LiveView.Utils.assign(:icon, session["icon"] || "hero-home")
       |> Phoenix.LiveView.Utils.assign(:active, session["active"] || false)
       |> Phoenix.LiveView.Utils.assign(:label, session["label"] || "Home")}
    end

    def render(assigns) do
      ~H"""
      <.sidebar_link href={@href} icon={@icon} active={@active}>
        {@label}
      </.sidebar_link>
      """
    end
  end

  describe "sidebar_link" do
    test "renders link with href, icon and label", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, SidebarLinkTestLive,
          session: %{"href" => "/dashboard", "icon" => "hero-cog", "label" => "Settings"}
        )

      assert html =~ "hero-cog"
      assert html =~ "Settings"
      assert html =~ "/dashboard"
    end

    test "applies active styles when active", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, SidebarLinkTestLive, session: %{"active" => true, "label" => "Active"})

      assert html =~ "Active"
      assert html =~ "bg-primary"
    end
  end

  describe "get_initials" do
    test "returns initials from email" do
      assert Sidebar.get_initials("john.doe@example.com") == "JD"
    end

    test "handles single part before @" do
      assert Sidebar.get_initials("admin@example.com") == "A"
    end

    test "returns ?? for non-binary" do
      assert Sidebar.get_initials(nil) == "??"
    end
  end
end
