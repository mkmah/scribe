defmodule SocialScribeWeb.Components.UI.TooltipTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule TooltipTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:content, session["content"] || "Tooltip text")
       |> Phoenix.LiveView.Utils.assign(:position, session["position"] || "top")}
    end

    def render(assigns) do
      ~H"""
      <.tooltip content={@content} position={@position}>
        <.tooltip_trigger>
          <.button>Hover</.button>
        </.tooltip_trigger>
      </.tooltip>
      """
    end
  end

  defmodule TooltipContentSlotTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.tooltip>
        <.tooltip_trigger>
          <.button>Trigger</.button>
        </.tooltip_trigger>
        <.tooltip_content>Slot content</.tooltip_content>
      </.tooltip>
      """
    end
  end

  defmodule SimpleTooltipTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:text, session["text"] || "Tooltip")}
    end

    def render(assigns) do
      ~H"""
      <.simple_tooltip text={@text}>
        <span>Target</span>
      </.simple_tooltip>
      """
    end
  end

  describe "UI.Tooltip" do
    test "renders tooltip with content and trigger", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TooltipTestLive, session: %{"content" => "Help text"})
      assert html =~ "Help text"
      assert html =~ "Hover"
    end

    test "renders tooltip with tooltip_content slot", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TooltipContentSlotTestLive, [])
      assert html =~ "Slot content"
      assert html =~ "role=\"tooltip\""
    end

    test "renders simple_tooltip", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, SimpleTooltipTestLive, session: %{"text" => "Hint"})
      assert html =~ "Hint"
    end

    test "tooltip position variants", %{conn: conn} do
      for position <- ["bottom", "left", "right"] do
        {:ok, _view, html} =
          live_isolated(conn, TooltipTestLive,
            session: %{"content" => "Pos", "position" => position}
          )
        assert html =~ "data-tooltip-position=\"#{position}\""
      end
    end
  end
end
