defmodule SocialScribeWeb.Components.UI.AlertTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule AlertTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:variant, session["variant"] || "default")
       |> Phoenix.LiveView.Utils.assign(:title, session["title"] || "Title")
       |> Phoenix.LiveView.Utils.assign(:description, session["description"] || "Description")}
    end

    def render(assigns) do
      ~H"""
      <.alert variant={@variant}>
        <.alert_title>{@title}</.alert_title>
        <.alert_description>{@description}</.alert_description>
      </.alert>
      """
    end
  end

  defmodule AlertToastTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:id, session["id"] || "toast-1")
       |> Phoenix.LiveView.Utils.assign(:title, session["title"])
       |> Phoenix.LiveView.Utils.assign(:variant, session["variant"] || "default")
       |> Phoenix.LiveView.Utils.assign(:show, session["show"] || false)}
    end

    def render(assigns) do
      ~H"""
      <.toast id={@id} title={@title} variant={@variant} show={@show}>
        Toast body
      </.toast>
      """
    end
  end

  defmodule AlertFlashTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:flash, session["flash"] || %{})
       |> Phoenix.LiveView.Utils.assign(:kind, session["kind"] || :info)}
    end

    def render(assigns) do
      ~H"""
      <.flash flash={@flash} kind={@kind} />
      """
    end
  end

  defmodule AlertFlashToastTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:flash, session["flash"] || %{})
       |> Phoenix.LiveView.Utils.assign(:duration, session["duration"] || 5000)}
    end

    def render(assigns) do
      ~H"""
      <.flash_toast flash={@flash} duration={@duration} />
      """
    end
  end

  describe "UI.Alert" do
    test "renders alert with role and slot content", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertTestLive,
          session: %{"title" => "Heads up!", "description" => "You can add components."}
        )

      assert html =~ "role=\"alert\""
      assert html =~ "Heads up!"
      assert html =~ "You can add components."
    end

    test "renders alert with destructive variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertTestLive,
          session: %{
            "variant" => "destructive",
            "title" => "Error",
            "description" => "Something went wrong."
          }
        )

      assert html =~ "Error"
      assert html =~ "text-destructive"
    end

    test "renders alert with success variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertTestLive,
          session: %{"variant" => "success", "title" => "Done", "description" => "Saved."}
        )

      assert html =~ "Done"
      assert html =~ "text-success"
    end

    test "renders alert with warning variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertTestLive,
          session: %{"variant" => "warning", "title" => "Caution", "description" => "Check this."}
        )

      assert html =~ "Caution"
      assert html =~ "text-warning"
    end

    test "renders alert with info variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertTestLive,
          session: %{"variant" => "info", "title" => "Info", "description" => "For your info."}
        )

      assert html =~ "Info"
      assert html =~ "text-info"
    end

    test "toast renders with id and optional title", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertToastTestLive,
          session: %{"id" => "my-toast", "title" => "Notice"}
        )

      assert html =~ "my-toast"
      assert html =~ "Notice"
      assert html =~ "Toast body"
    end

    test "flash renders when flash has message for kind", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertFlashTestLive,
          session: %{"flash" => %{"info" => "Hello"}, "kind" => :info}
        )

      assert html =~ "Hello"
      assert html =~ "role=\"alert\""
    end

    test "flash_toast renders entries from flash", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertFlashToastTestLive,
          session: %{"flash" => %{"success" => "Saved!", "error" => "Failed"}}
        )

      assert html =~ "flash-toast-container"
    end

    test "flash renders error kind", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertFlashTestLive,
          session: %{"flash" => %{"error" => "Something failed"}, "kind" => :error}
        )

      assert html =~ "Something failed"
    end

    test "flash renders success kind", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertFlashTestLive,
          session: %{"flash" => %{"success" => "Done"}, "kind" => :success}
        )

      assert html =~ "Done"
    end

    test "flash renders warning kind", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertFlashTestLive,
          session: %{"flash" => %{"warning" => "Careful"}, "kind" => :warning}
        )

      assert html =~ "Careful"
    end

    test "toast with show true has phx-mounted", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AlertToastTestLive, session: %{"id" => "t1", "show" => true})

      assert html =~ "phx-mounted"
    end
  end
end
