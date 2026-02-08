defmodule SocialScribeWeb.Components.UI.AvatarTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule AvatarTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:fallback, session["fallback"])
       |> Phoenix.LiveView.Utils.assign(:src, session["src"])
       |> Phoenix.LiveView.Utils.assign(:size, session["size"] || "default")
       |> Phoenix.LiveView.Utils.assign(:class, session["class"])}
    end

    def render(assigns) do
      ~H"""
      <.avatar fallback={@fallback} src={@src} size={@size} class={@class} />
      """
    end
  end

  defmodule AvatarGroupTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:class, session["class"])}
    end

    def render(assigns) do
      ~H"""
      <.avatar_group class={@class}>
        <.avatar fallback="A" />
        <.avatar fallback="B" />
      </.avatar_group>
      """
    end
  end

  describe "UI.Avatar" do
    test "renders avatar with fallback text", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AvatarTestLive, session: %{"fallback" => "JD"})

      assert html =~ "JD"
      assert html =~ "rounded-full"
    end

    test "renders avatar with src and fallback", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AvatarTestLive,
          session: %{"src" => "/img.png", "fallback" => "AB"}
        )

      assert html =~ "src=\"/img.png\""
      assert html =~ "AB"
    end

    test "avatar_group renders multiple avatars", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AvatarGroupTestLive, session: %{})
      assert html =~ "-space-x-2"
      assert html =~ "A"
      assert html =~ "B"
    end

    test "renders avatar with no fallback shows user icon", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AvatarTestLive, session: %{})
      assert html =~ "rounded-full"
      assert html =~ "M19 21v-2a4 4 0 0 0-4-4H9"
    end

    test "renders avatar size variants", %{conn: conn} do
      for {size, class_fragment} <- [
            {"xs", "h-6 w-6"},
            {"sm", "h-8 w-8"},
            {"lg", "h-12 w-12"},
            {"xl", "h-14 w-14"}
          ] do
        {:ok, _view, html} =
          live_isolated(conn, AvatarTestLive, session: %{"size" => size, "fallback" => "X"})
        assert html =~ class_fragment
      end
    end

    test "renders avatar with custom class", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AvatarTestLive,
          session: %{"fallback" => "Y", "class" => "avatar-custom"}
        )
      assert html =~ "avatar-custom"
    end

    test "avatar_group with custom class", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, AvatarGroupTestLive, session: %{"class" => "group-class"})
      assert html =~ "group-class"
    end
  end
end
