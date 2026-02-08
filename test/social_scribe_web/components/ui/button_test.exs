defmodule SocialScribeWeb.Components.UI.ButtonTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule ButtonTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:variant, session["variant"] || "default")
       |> Phoenix.LiveView.Utils.assign(:size, session["size"] || "default")
       |> Phoenix.LiveView.Utils.assign(:disabled, session["disabled"] || false)
       |> Phoenix.LiveView.Utils.assign(:loading, session["loading"] || false)
       |> Phoenix.LiveView.Utils.assign(:content, session["content"] || "Click me")
       |> Phoenix.LiveView.Utils.assign(:class, session["class"])}
    end

    def render(assigns) do
      ~H"""
      <.button variant={@variant} size={@size} disabled={@disabled} loading={@loading} class={@class}>
        {@content}
      </.button>
      """
    end
  end

  defmodule IconButtonTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:variant, session["variant"] || "default")
       |> Phoenix.LiveView.Utils.assign(:size, session["size"] || "default")
       |> Phoenix.LiveView.Utils.assign(:loading, session["loading"] || false)
       |> Phoenix.LiveView.Utils.assign(:disabled, session["disabled"] || false)}
    end

    def render(assigns) do
      ~H"""
      <.icon_button variant={@variant} size={@size} loading={@loading} disabled={@disabled}>
        <.icon name="hero-plus" class="w-4 h-4" />
      </.icon_button>
      """
    end
  end

  describe "UI.Button" do
    test "renders button with default variant and slot content", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive, session: %{"content" => "Click me"})

      assert html =~ "Click me"
      assert html =~ "<button"
      assert html =~ "type=\"button\""
    end

    test "renders button with primary variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"variant" => "primary", "content" => "Save"}
        )

      assert html =~ "Save"
      assert html =~ "bg-primary"
    end

    test "renders disabled button", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"disabled" => true, "content" => "Disabled"}
        )

      assert html =~ "disabled"
      assert html =~ "Disabled"
    end

    test "renders loading button with spinner", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"loading" => true, "content" => "Loading..."}
        )

      assert html =~ "animate-spin"
      assert html =~ "Loading..."
    end

    test "icon_button renders slot content", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IconButtonTestLive, [])

      assert html =~ "hero-plus"
      assert html =~ "<button"
    end

    test "renders button with link variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive, session: %{"variant" => "link", "content" => "Link"})

      assert html =~ "Link"
      assert html =~ "text-primary"
      assert html =~ "underline"
    end

    test "renders button with size sm", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive, session: %{"size" => "sm", "content" => "Small"})

      assert html =~ "Small"
      assert html =~ "h-9"
    end

    test "renders button with size lg", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive, session: %{"size" => "lg", "content" => "Large"})

      assert html =~ "Large"
      assert html =~ "h-11"
    end

    test "renders button with size xs", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive, session: %{"size" => "xs", "content" => "Tiny"})

      assert html =~ "Tiny"
      assert html =~ "h-8"
    end

    test "renders button with secondary variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"variant" => "secondary", "content" => "Sec"}
        )

      assert html =~ "Sec"
      assert html =~ "bg-secondary"
    end

    test "renders button with outline variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"variant" => "outline", "content" => "Out"}
        )

      assert html =~ "Out"
      assert html =~ "border-border"
    end

    test "renders button with ghost variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"variant" => "ghost", "content" => "Ghost"}
        )

      assert html =~ "Ghost"
      assert html =~ "hover:bg-accent"
    end

    test "renders button with destructive variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"variant" => "destructive", "content" => "Delete"}
        )

      assert html =~ "Delete"
      assert html =~ "bg-destructive"
    end

    test "renders button with size icon", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive, session: %{"size" => "icon", "content" => "🔘"})

      assert html =~ "h-10 w-10"
    end

    test "renders button with custom class", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ButtonTestLive,
          session: %{"content" => "Custom", "class" => "my-custom-class"}
        )

      assert html =~ "Custom"
      assert html =~ "my-custom-class"
    end

    test "icon_button with loading shows spinner", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IconButtonTestLive, session: %{"loading" => true})
      assert html =~ "animate-spin"
      assert html =~ "cursor-wait"
    end

    test "icon_button with outline variant and sizes xs sm lg", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive,
          session: %{"variant" => "outline", "size" => "sm"}
        )

      assert html =~ "border-border"
      assert html =~ "h-9 w-9"

      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive, session: %{"size" => "xs"})

      assert html =~ "h-8 w-8"

      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive, session: %{"size" => "lg"})

      assert html =~ "h-11 w-11"
    end

    test "icon_button disabled", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive, session: %{"disabled" => true})

      assert html =~ "disabled"
    end

    test "icon_button with size icon", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive, session: %{"size" => "icon"})

      assert html =~ "h-10 w-10"
    end

    test "icon_button variant secondary and ghost and destructive", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive, session: %{"variant" => "secondary"})

      assert html =~ "bg-secondary"

      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive, session: %{"variant" => "ghost"})

      assert html =~ "hover:bg-accent"

      {:ok, _view, html} =
        live_isolated(conn, IconButtonTestLive, session: %{"variant" => "destructive"})

      assert html =~ "bg-destructive"
    end
  end
end
