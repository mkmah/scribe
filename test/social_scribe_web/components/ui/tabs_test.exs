defmodule SocialScribeWeb.Components.UI.TabsTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule TabsTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.tabs default="one" id="test-tabs">
        <:list>
          <.tabs_list>
            <.tabs_trigger value="one" tabs_id="test-tabs">One</.tabs_trigger>
            <.tabs_trigger value="two" tabs_id="test-tabs">Two</.tabs_trigger>
          </.tabs_list>
        </:list>
        <:content value="one">Content one</:content>
        <:content value="two">Content two</:content>
      </.tabs>
      """
    end
  end

  defmodule TabsNoDefaultAndVariantsTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.tabs id="no-default-tabs" class="tabs-container">
        <:list>
          <.tabs_list class="tabs-list-class">
            <.tabs_trigger value="a" tabs_id="no-default-tabs">Tab A</.tabs_trigger>
            <.tabs_trigger value="b" tabs_id="no-default-tabs" disabled>Tab B disabled</.tabs_trigger>
          </.tabs_list>
        </:list>
        <:content value="a">First content</:content>
        <:content value="b">Second content</:content>
      </.tabs>
      <.tabs_content value="standalone" class="tabs-content-class">Standalone panel</.tabs_content>
      """
    end
  end

  describe "UI.Tabs" do
    test "renders tabs with list and content", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TabsTestLive, [])

      assert html =~ "One"
      assert html =~ "Two"
      assert html =~ "Content one"
      assert html =~ "Content two"
      assert html =~ "test-tabs"
    end

    test "tabs without default uses first content value, tabs_list/trigger/content variants and disabled trigger", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TabsNoDefaultAndVariantsTestLive, [])

      assert html =~ "no-default-tabs"
      assert html =~ "data-default-tab=\"a\""
      assert html =~ "tabs-container"
      assert html =~ "tabs-list-class"
      assert html =~ "Tab A"
      assert html =~ "Tab B disabled"
      assert html =~ "disabled"
      assert html =~ "First content"
      assert html =~ "Second content"
      assert html =~ "Standalone panel"
      assert html =~ "tabs-content-class"
      assert html =~ "role=\"tabpanel\""
    end
  end
end
