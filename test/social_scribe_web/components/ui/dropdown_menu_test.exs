defmodule SocialScribeWeb.Components.UI.DropdownMenuTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule DropdownMenuTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.dropdown_menu>
        <.dropdown_menu_trigger>
          <.button variant="outline">Open</.button>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content>
          <.dropdown_menu_item>Item</.dropdown_menu_item>
        </.dropdown_menu_content>
      </.dropdown_menu>
      """
    end
  end

  defmodule DropdownMenuFullTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:align, session["align"] || "center")
       |> Phoenix.LiveView.Utils.assign(:side, session["side"] || "bottom")
       |> Phoenix.LiveView.Utils.assign(:id, session["id"])
       |> Phoenix.LiveView.Utils.assign(:class, session["class"])
       |> Phoenix.LiveView.Utils.assign(:as_child, session["as_child"] || false)}
    end

    def render(assigns) do
      ~H"""
      <.dropdown_menu id={@id} align={@align} side={@side} class={@class}>
        <.dropdown_menu_trigger dropdown_id={@id} as_child={@as_child} class={@class}>
          <.avatar fallback="JD" />
        </.dropdown_menu_trigger>
        <.dropdown_menu_content align={@align} side={@side}>
          <.dropdown_menu_label>My Account</.dropdown_menu_label>
          <.dropdown_menu_separator />
          <.dropdown_menu_group>
            <.dropdown_menu_item>Profile</.dropdown_menu_item>
            <.dropdown_menu_item variant="destructive">Delete</.dropdown_menu_item>
            <.dropdown_menu_item disabled>Disabled</.dropdown_menu_item>
          </.dropdown_menu_group>
        </.dropdown_menu_content>
      </.dropdown_menu>
      """
    end
  end

  describe "UI.DropdownMenu" do
    test "renders dropdown with trigger and content", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, DropdownMenuTestLive, [])

      assert html =~ "Open"
      assert html =~ "Item"
    end

    test "renders dropdown with label, separator, group, item variants and as_child trigger", %{
      conn: conn
    } do
      {:ok, _view, html} =
        live_isolated(conn, DropdownMenuFullTestLive,
          session: %{"id" => "full-menu", "as_child" => true}
        )

      assert html =~ "My Account"
      assert html =~ "Profile"
      assert html =~ "Delete"
      assert html =~ "Disabled"
      assert html =~ "data-variant=\"destructive\""
      assert html =~ "full-menu"
      assert html =~ "data-dropdown-content"
      assert html =~ "role=\"group\""
    end

    test "dropdown_menu_content position start bottom and end top", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, DropdownMenuFullTestLive,
          session: %{"id" => "d1", "align" => "start", "side" => "bottom"}
        )

      assert html =~ "origin-top-left"
      assert html =~ "left-0 top-full"

      {:ok, _view, html} =
        live_isolated(conn, DropdownMenuFullTestLive,
          session: %{"id" => "d2", "align" => "end", "side" => "bottom"}
        )

      assert html =~ "origin-top-right"

      {:ok, _view, html} =
        live_isolated(conn, DropdownMenuFullTestLive,
          session: %{"id" => "d3", "align" => "end", "side" => "top"}
        )

      assert html =~ "origin-bottom-right"
      assert html =~ "bottom-full"

      {:ok, _view, html} =
        live_isolated(conn, DropdownMenuFullTestLive,
          session: %{"id" => "d4", "align" => "start", "side" => "top"}
        )

      assert html =~ "origin-bottom-left"

      {:ok, _view, html} =
        live_isolated(conn, DropdownMenuFullTestLive,
          session: %{"id" => "d5", "align" => "center", "side" => "top"}
        )

      assert html =~ "origin-bottom"
      assert html =~ "-translate-x-1/2"
    end

    test "dropdown_menu with custom class", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, DropdownMenuFullTestLive,
          session: %{"id" => "d6", "class" => "dropdown-custom"}
        )

      assert html =~ "dropdown-custom"
    end
  end
end
