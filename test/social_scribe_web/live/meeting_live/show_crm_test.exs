defmodule SocialScribeWeb.MeetingLive.ShowCrmTest do
  use SocialScribeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.MeetingsFixtures

  describe "CRM Button Visibility" do
    setup :register_and_log_in_user

    setup %{user: user} do
      # Create meeting and credentials for both CRMs
      meeting = meeting_for_user(user)
      hubspot_credential_fixture(user_id: user.id)
      salesforce_credential_fixture(user_id: user.id)

      on_exit(fn ->
        Application.delete_env(:social_scribe, :crm_api)
      end)

      %{meeting: meeting}
    end

    test "shows all CRM buttons when no global config is set", %{conn: conn, meeting: meeting} do
      Application.delete_env(:social_scribe, :crm_api)

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # When no CRM is associated, shows "Use" buttons
      assert html =~ "Use HubSpot"
      assert html =~ "Use Salesforce"
    end

    test "shows only configured CRM button when global config is set", %{
      conn: conn,
      meeting: meeting
    } do
      # Simulate global config pointing to HubSpot adapter
      Application.put_env(:social_scribe, :crm_api, SocialScribe.Crm.Adapters.Hubspot)

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # When no CRM is associated, shows "Use" buttons
      assert html =~ "Use HubSpot"
      refute html =~ "Use Salesforce"
      refute html =~ "Update Salesforce"
    end
  end

  defp meeting_for_user(user) do
    credential = user_credential_fixture(%{user_id: user.id})
    # Ensure event has a user_credential_id
    event = calendar_event_fixture(%{user_id: user.id, user_credential_id: credential.id})
    meeting_fixture(%{calendar_event_id: event.id, title: "CRM Test Meeting"})
  end
end
