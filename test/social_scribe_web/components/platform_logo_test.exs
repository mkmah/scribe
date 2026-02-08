defmodule SocialScribeWeb.Components.PlatformLogoTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  use SocialScribeWeb, :html

  defmodule PlatformLogoTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.PlatformLogo

    def mount(_params, session, socket) do
      meeting_url = session["meeting_url"] || "https://meet.google.com/abc"
      recall_bot = %{meeting_url: meeting_url}
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:recall_bot, recall_bot)
       |> Phoenix.LiveView.Utils.assign(:class, session["class"] || "h-5 w-5")}
    end

    def render(assigns) do
      ~H"""
      <.platform_logo recall_bot={@recall_bot} class={@class} />
      """
    end
  end

  describe "platform_logo" do
    test "renders Google Meet logo for meet.google.com URL", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, PlatformLogoTestLive,
          session: %{"meeting_url" => "https://meet.google.com/abc-def"}
        )

      # Google Meet logo (HTML lowercases attribute names)
      assert html =~ "viewbox=\"0 0 87.5 72\""
      assert html =~ "00832d"
    end

    test "renders Zoom logo for zoom.us URL", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, PlatformLogoTestLive,
          session: %{"meeting_url" => "https://zoom.us/j/123"}
        )

      assert html =~ "viewbox=\"0 0 512 512\""
      assert html =~ "2D8CFF"
    end

    test "defaults to Google Meet for unknown URL", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, PlatformLogoTestLive,
          session: %{"meeting_url" => "https://other.com/meeting"}
        )

      assert html =~ "viewbox=\"0 0 87.5 72\""
    end
  end
end
