defmodule SocialScribeWeb.Components.ThemeToggleTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  use SocialScribeWeb, :html

  defmodule ThemeToggleTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.Theme.ThemeToggle

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.theme_toggle />
      """
    end
  end

  describe "theme_toggle" do
    test "renders with theme options Light, Dark, System", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, ThemeToggleTestLive, [])

      assert html =~ "Light"
      assert html =~ "Dark"
      assert html =~ "System"
      assert html =~ "theme-toggle"
      assert html =~ "Toggle theme"
    end
  end
end
