defmodule SocialScribeWeb.Components.UI.BadgeTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule BadgeTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      variant = session["variant"]
      variant = if variant == "primary_atom", do: :primary, else: (variant || "default")
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:variant, variant)
       |> Phoenix.LiveView.Utils.assign(:content, session["content"] || "Badge")
       |> Phoenix.LiveView.Utils.assign(:class, session["class"])}
    end

    def render(assigns) do
      ~H"""
      <.badge variant={@variant} class={@class}>{@content}</.badge>
      """
    end
  end

  defmodule StatusBadgeTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:status, session["status"] || "active")
       |> Phoenix.LiveView.Utils.assign(:content, session["content"] || "Active")
       |> Phoenix.LiveView.Utils.assign(:class, session["class"])}
    end

    def render(assigns) do
      ~H"""
      <.status_badge status={@status} class={@class}>{@content}</.status_badge>
      """
    end
  end

  describe "UI.Badge" do
    test "renders badge with default variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive, session: %{"content" => "Default"})

      assert html =~ "Default"
      assert html =~ "bg-primary"
    end

    test "renders badge with primary variant (string)", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "primary", "content" => "Primary"}
        )
      assert html =~ "Primary"
      assert html =~ "bg-primary"
    end

    test "renders badge with primary variant (atom)", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "primary_atom", "content" => "Primary"}
        )
      assert html =~ "Primary"
      assert html =~ "bg-primary"
    end

    test "renders badge with custom class", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"content" => "Badge", "class" => "custom-badge-class"}
        )
      assert html =~ "custom-badge-class"
    end

    test "renders badge with destructive variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "destructive", "content" => "Error"}
        )

      assert html =~ "Error"
      assert html =~ "destructive"
    end

    test "status_badge renders with dot and content", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, StatusBadgeTestLive,
          session: %{"status" => "active", "content" => "Connected"}
        )

      assert html =~ "Connected"
      assert html =~ "rounded-full"
    end

    test "renders badge with secondary variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "secondary", "content" => "Sec"}
        )

      assert html =~ "Sec"
      assert html =~ "bg-secondary"
    end

    test "renders badge with outline variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "outline", "content" => "Out"}
        )

      assert html =~ "Out"
      assert html =~ "text-foreground"
    end

    test "renders badge with success variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "success", "content" => "OK"}
        )

      assert html =~ "OK"
      assert html =~ "bg-success"
    end

    test "renders badge with warning variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "warning", "content" => "Warn"}
        )

      assert html =~ "Warn"
      assert html =~ "bg-warning"
    end

    test "renders badge with info variant", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, BadgeTestLive,
          session: %{"variant" => "info", "content" => "Info"}
        )

      assert html =~ "Info"
      assert html =~ "bg-info"
    end

    test "status_badge pending", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, StatusBadgeTestLive,
          session: %{"status" => "pending", "content" => "Pending"}
        )

      assert html =~ "Pending"
      assert html =~ "bg-warning"
    end

    test "status_badge error", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, StatusBadgeTestLive,
          session: %{"status" => "error", "content" => "Error"}
        )

      assert html =~ "Error"
      assert html =~ "bg-destructive"
    end

    test "status_badge inactive", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, StatusBadgeTestLive,
          session: %{"status" => "inactive", "content" => "Inactive"}
        )

      assert html =~ "Inactive"
      assert html =~ "bg-muted"
    end

    test "status_badge success", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, StatusBadgeTestLive,
          session: %{"status" => "success", "content" => "Done"}
        )
      assert html =~ "Done"
      assert html =~ "bg-success"
    end

    test "status_badge with custom class", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, StatusBadgeTestLive,
          session: %{"status" => "active", "content" => "OK", "class" => "status-class"}
        )
      assert html =~ "status-class"
    end
  end
end
