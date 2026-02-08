defmodule SocialScribeWeb.Components.ClipboardButtonTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule ClipboardButtonWrapperLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.ClipboardButton

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:id, session["id"] || "clip-test")
       |> Phoenix.LiveView.Utils.assign(:text, session["text"] || "copy this")}
    end

    def render(assigns) do
      ~H"""
      <.clipboard_button id={@id} text={@text} />
      """
    end
  end

  defmodule WrapperLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:id, session["id"] || "clip-test")
       |> Phoenix.LiveView.Utils.assign(:text, session["text"] || "copy this")}
    end

    def render(assigns) do
      ~H"""
      <.live_component
        module={SocialScribeWeb.ClipboardButtonComponent}
        id={@id}
        text={@text}
      />
      """
    end
  end

  describe "ClipboardButton (function component)" do
    test "renders via clipboard_button component", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ClipboardButtonWrapperLive, session: %{"id" => "cb1", "text" => "copy me"})

      assert html =~ "Copy"
      assert html =~ "hero-clipboard"
    end
  end

  describe "ClipboardButtonComponent" do
    test "renders Copy button with text", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, WrapperLive, session: %{"text" => "copy this"})

      assert html =~ "Copy"
      assert html =~ "hero-clipboard"
    end

    test "copy event pushes copy-to-clipboard", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"text" => "hello world"})

      view
      |> element("button[phx-click=\"copy\"]")
      |> render_click()

      assert_push_event(view, "copy-to-clipboard", %{text: "hello world"})
    end
  end
end
