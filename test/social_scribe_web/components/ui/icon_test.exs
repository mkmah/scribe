defmodule SocialScribeWeb.Components.UI.IconTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule IconTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.icon name="hero-home" class="h-4 w-4" />
      <.check class="h-4 w-4" />
      <.x class="h-4 w-4" />
      """
    end
  end

  defmodule IconFlashIconsTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.UI.Icon, only: [info: 1, circle_alert: 1, circle_check: 1, triangle_alert: 1]

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.info class="h-5 w-5" />
      <.circle_alert class="h-5 w-5" />
      <.circle_check class="h-5 w-5" />
      <.triangle_alert class="h-5 w-5" />
      """
    end
  end

  defmodule IconCheckListClassTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.UI.Icon, only: [check: 1]

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.check class={["h-4 w-4", "custom"]} />
      """
    end
  end

  defmodule AllIconsTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.UI.Icon

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.icon name="hero-home" class="h-4 w-4" />
      <.chevron_down class="h-4 w-4" />
      <.chevron_up class="h-4 w-4" />
      <.chevron_left class="h-4 w-4" />
      <.chevron_right class="h-4 w-4" />
      <.spinner class="h-4 w-4" />
      <.search class="h-4 w-4" />
      <.more_horizontal class="h-4 w-4" />
      <.more_vertical class="h-4 w-4" />
      <.trash class="h-4 w-4" />
      <.edit class="h-4 w-4" />
      <.copy class="h-4 w-4" />
      <.sun class="h-4 w-4" />
      <.moon class="h-4 w-4" />
      <.monitor class="h-4 w-4" />
      <.user class="h-4 w-4" />
      <.settings class="h-4 w-4" />
      <.logout class="h-4 w-4" />
      """
    end
  end

  describe "UI.Icon" do
    test "renders icon and named icons", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IconTestLive, [])

      assert html =~ "hero-home"
      assert html =~ "svg"
    end

    test "renders Icon.info, circle_alert, circle_check, triangle_alert", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IconFlashIconsTestLive, [])
      assert html =~ "svg"
    end

    test "Icon.check with list class", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IconCheckListClassTestLive, [])
      assert html =~ "svg"
      assert html =~ "h-4 w-4"
    end

    test "renders all Icon components (chevron, spinner, search, more, trash, edit, copy, sun, moon, monitor, user, settings, logout)", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AllIconsTestLive, [])
      assert html =~ "hero-home"
      assert html =~ "animate-spin"
      assert html =~ "viewbox=\"0 0 24 24\""
      assert html =~ "m6 9 6 6 6-6"
      assert html =~ "m18 15-6-6-6 6"
      assert html =~ "m15 18-6-6 6-6"
      assert html =~ "m9 18 6-6-6-6"
      assert html =~ "M21 12a9 9 0 1 1-6.219-8.56"
      assert html =~ "m21 21-4.3-4.3"
      assert html =~ "M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"
      assert html =~ "M19 21v-2a4 4 0 0 0-4-4H9"
      assert html =~ "polyline points=\"16 17 21 12 16 7\""
    end
  end
end
