defmodule SocialScribeWeb.Components.UI.SeparatorTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule SeparatorTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:orientation, session["orientation"] || "horizontal")}
    end

    def render(assigns) do
      ~H"""
      <.separator orientation={@orientation} />
      """
    end
  end

  describe "UI.Separator" do
    test "renders horizontal separator by default", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, SeparatorTestLive, [])

      assert html =~ "bg-border"
    end

    test "renders vertical separator", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, SeparatorTestLive, session: %{"orientation" => "vertical"})

      assert html =~ "bg-border"
    end
  end
end
