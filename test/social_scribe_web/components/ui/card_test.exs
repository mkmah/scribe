defmodule SocialScribeWeb.Components.UI.CardTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule CardTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.card>
        <:header>
          <.card_title>Card Title</.card_title>
          <.card_description>Card description</.card_description>
        </:header>
        <.card_content>
          <p>Card body</p>
        </.card_content>
        <:footer>
          <.button>Action</.button>
        </:footer>
      </.card>
      """
    end
  end

  defmodule CardWithClassTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:class, session["class"])}
    end

    def render(assigns) do
      ~H"""
      <.card class={@class}>
        <:header>
          <.card_header>
            <.card_title>Header Title</.card_title>
            <.card_description>Header desc</.card_description>
          </.card_header>
        </:header>
        <.card_content>
          <p>Body</p>
        </.card_content>
        <:footer>
          <.card_footer>
            <.button>Footer action</.button>
          </.card_footer>
        </:footer>
      </.card>
      """
    end
  end

  defmodule CardNoHeaderTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.card>
        <.card_content>
          <p>Body only</p>
        </.card_content>
        <:footer>
          <.button>Action</.button>
        </:footer>
      </.card>
      """
    end
  end

  defmodule CardNoFooterTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.card>
        <:header>
          <.card_title>Title</.card_title>
        </:header>
        <.card_content>
          <p>Body</p>
        </.card_content>
      </.card>
      """
    end
  end

  defmodule CardMinimalTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.card>
        <.card_content>
          <p>Minimal content</p>
        </.card_content>
      </.card>
      """
    end
  end

  describe "UI.Card" do
    test "renders card with header, content, and footer", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, CardTestLive, [])

      assert html =~ "Card Title"
      assert html =~ "Card description"
      assert html =~ "Card body"
      assert html =~ "Action"
      assert html =~ "border-border"
    end

    test "renders card with string class and card_header/card_footer", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, CardWithClassTestLive, session: %{"class" => "w-[350px]"})
      assert html =~ "w-[350px]"
      assert html =~ "Header Title"
      assert html =~ "Body"
      assert html =~ "Footer action"
    end

    test "renders card with list class", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, CardWithClassTestLive,
          session: %{"class" => ["list-class", nil, "another-class"]}
        )
      assert html =~ "list-class"
      assert html =~ "another-class"
    end

    test "renders card with no header slot", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, CardNoHeaderTestLive, [])
      assert html =~ "Body only"
      assert html =~ "Action"
    end

    test "renders card with no footer slot", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, CardNoFooterTestLive, [])
      assert html =~ "Title"
      assert html =~ "Body"
    end

    test "renders card with no header and no footer", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, CardMinimalTestLive, [])
      assert html =~ "Minimal content"
    end
  end
end
