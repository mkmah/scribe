defmodule SocialScribeWeb.Components.UI.DialogTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule DialogTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:show, session["show"] || false)
       |> Phoenix.LiveView.Utils.assign(:id, session["id"] || "test-dialog")
       |> Phoenix.LiveView.Utils.assign(:size, session["size"] || "md")}
    end

    def render(assigns) do
      ~H"""
      <.dialog id={@id} show={@show} size={@size}>
        <:header>
          <.dialog_title>Title</.dialog_title>
        </:header>
        <:content>
          <p>Content</p>
        </:content>
      </.dialog>
      """
    end
  end

  defmodule DialogWithFooterAndTriggerTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.dialog_trigger target="open-dialog">
        <.button>Open</.button>
      </.dialog_trigger>
      <.dialog id="open-dialog" show={false}>
        <:header>
          <.dialog_title>Dialog</.dialog_title>
        </:header>
        <:content>
          <p>Body</p>
        </:content>
        <:footer>
          <.button>Footer button</.button>
        </:footer>
      </.dialog>
      """
    end
  end

  defmodule DialogInnerBlockAndSubcomponentsTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.dialog id="inner-block-dialog" show={false} class="custom-dialog-class">
        <:header>
          <.dialog_header>
            <.dialog_title>Header Title</.dialog_title>
            <.dialog_description>Header description text</.dialog_description>
          </.dialog_header>
        </:header>
        Inner block content only
        <:footer>
          <.dialog_footer>
            <.button>OK</.button>
          </.dialog_footer>
        </:footer>
      </.dialog>
      """
    end
  end

  defmodule DialogNoHeaderNoContentSlotsTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.dialog id="minimal-dialog" show={false}>
        No header, no content slot — inner block only.
      </.dialog>
      """
    end
  end

  describe "UI.Dialog" do
    test "renders dialog structure with id and slots", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, DialogTestLive, session: %{"id" => "my-dialog"})

      assert html =~ "my-dialog"
      assert html =~ "Title"
      assert html =~ "Content"
    end

    test "dialog with show true mounts with phx-mounted", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, DialogTestLive, session: %{"id" => "open-dialog", "show" => true})

      assert html =~ "open-dialog"
      assert html =~ "phx-mounted"
    end

    test "dialog size variants", %{conn: conn} do
      for size <- ["sm", "lg", "xl", "full"] do
        {:ok, _view, html} =
          live_isolated(conn, DialogTestLive, session: %{"id" => "d-#{size}", "size" => size})

        assert html =~ "d-#{size}"
      end
    end

    test "dialog with footer and dialog_trigger", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, DialogWithFooterAndTriggerTestLive, [])
      assert html =~ "open-dialog"
      assert html =~ "Open"
      assert html =~ "Footer button"
    end

    test "dialog with inner_block when no content slot uses dialog_header, dialog_description, dialog_footer",
         %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, DialogInnerBlockAndSubcomponentsTestLive, [])
      assert html =~ "inner-block-dialog"
      assert html =~ "Header Title"
      assert html =~ "Header description text"
      assert html =~ "Inner block content only"
      assert html =~ "custom-dialog-class"
      assert html =~ "OK"
    end

    test "dialog with no header and no content slot renders inner_block only", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, DialogNoHeaderNoContentSlotsTestLive, [])
      assert html =~ "minimal-dialog"
      assert html =~ "No header, no content slot — inner block only."
    end

    test "show_modal and hide_modal accept optional JS as first argument", %{conn: _conn} do
      js = Phoenix.LiveView.JS.push("ok")
      show_result = SocialScribeWeb.UI.Dialog.show_modal(js, "modal-id")
      hide_result = SocialScribeWeb.UI.Dialog.hide_modal(js, "modal-id")
      assert %Phoenix.LiveView.JS{} = show_result
      assert %Phoenix.LiveView.JS{} = hide_result
    end
  end
end
