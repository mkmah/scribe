defmodule SocialScribeWeb.Components.UI.SwitchTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule SwitchTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:name, session["name"] || "toggle")
       |> Phoenix.LiveView.Utils.assign(:checked, session["checked"] || false)}
    end

    def render(assigns) do
      ~H"""
      <.switch name={@name} checked={@checked}>
        <:label>Label</:label>
      </.switch>
      """
    end
  end

  describe "UI.Switch" do
    test "renders switch with name and label", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, SwitchTestLive, session: %{"name" => "notifications"})

      assert html =~ "notifications"
      assert html =~ "Label"
      assert html =~ "checkbox"
    end
  end
end
