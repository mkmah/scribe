defmodule SocialScribeWeb.Components.IntegrationCardTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  use SocialScribeWeb, :html

  defmodule IntegrationCardTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.Components.IntegrationCard

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:name, session["name"] || "HubSpot")
       |> Phoenix.LiveView.Utils.assign(:description, session["description"] || "CRM")
       |> Phoenix.LiveView.Utils.assign(:connected, session["connected"] || false)
       |> Phoenix.LiveView.Utils.assign(:icon, session["icon"] || :hubspot)}
    end

    def render(assigns) do
      ~H"""
      <.integration_card name={@name} description={@description} connected={@connected} icon={@icon}>
        <:action>
          <.link href="/settings">Connect</.link>
        </:action>
      </.integration_card>
      """
    end
  end

  defmodule IntegrationCardWithConnectionListLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.Components.IntegrationCard

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.integration_card name="Google" description="Calendar" connected={true} icon={:google}>
        <:connection_list>
          <p>user@example.com</p>
        </:connection_list>
        <:action>
          <.button>Manage</.button>
        </:action>
      </.integration_card>
      """
    end
  end

  describe "integration_card" do
    test "renders name, description and Not Connected when disconnected", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, IntegrationCardTestLive,
          session: %{
            "name" => "Salesforce",
            "description" => "CRM integration",
            "connected" => false
          }
        )

      assert html =~ "Salesforce"
      assert html =~ "CRM integration"
      assert html =~ "Not Connected"
    end

    test "renders Connected when connected", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, IntegrationCardTestLive, session: %{"connected" => true})

      assert html =~ "Connected"
    end

    test "renders connection_list and action slots", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IntegrationCardWithConnectionListLive, [])

      assert html =~ "Google"
      assert html =~ "Calendar"
      assert html =~ "user@example.com"
      assert html =~ "Manage"
    end
  end
end
