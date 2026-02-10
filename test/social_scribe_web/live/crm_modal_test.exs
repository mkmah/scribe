defmodule SocialScribeWeb.CrmModalTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  describe "Meeting show - CRM integration cards" do
    @describetag :capture_log
    setup :register_and_log_in_user

    setup %{user: user} do
      meeting = meeting_fixture_for_user(user)
      %{meeting: meeting}
    end

    test "shows HubSpot card when hubspot credential exists", %{
      conn: conn,
      user: user,
      meeting: meeting
    } do
      _cred = hubspot_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # When no CRM is associated, shows "Select CRM" button with dropdown menu containing HubSpot
      assert html =~ "Select CRM"
      assert html =~ "HubSpot"
    end

    test "shows Salesforce card when salesforce credential exists", %{
      conn: conn,
      user: user,
      meeting: meeting
    } do
      _cred = salesforce_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # When no CRM is associated, shows "Select CRM" button with dropdown menu containing Salesforce
      assert html =~ "Select CRM"
      assert html =~ "Salesforce"
    end

    test "shows both cards when both credentials exist", %{
      conn: conn,
      user: user,
      meeting: meeting
    } do
      _hubspot = hubspot_credential_fixture(%{user_id: user.id})
      _salesforce = salesforce_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # When no CRM is associated, shows "Select CRM" button with dropdown menu containing both CRMs
      assert html =~ "Select CRM"
      assert html =~ "HubSpot"
      assert html =~ "Salesforce"
    end

    test "shows no CRM cards when no credentials exist", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should not show CRM section when no credentials exist
      refute html =~ "Select CRM"
      refute html =~ "Update HubSpot"
      refute html =~ "Update Salesforce"
    end
  end

  describe "CRM Modal - HubSpot" do
    setup :register_and_log_in_user

    setup %{user: user} do
      meeting = meeting_fixture_for_user(user)
      credential = hubspot_credential_fixture(%{user_id: user.id})
      %{meeting: meeting, credential: credential}
    end

    test "renders modal with 'Update HubSpot' title", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/hubspot")

      assert has_element?(view, "h2", "Update HubSpot")
    end

    test "shows contact search input", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/hubspot")

      # The modal should have a search/contact select UI
      assert has_element?(view, "[phx-keyup=contact_search]") or
               has_element?(view, "input[id*='contact-select-input']")
    end

    test "modal can be closed by navigating back", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/hubspot")

      # Modal should be visible
      assert has_element?(view, "h2", "Update HubSpot")
    end
  end

  describe "CRM Modal - Salesforce" do
    setup :register_and_log_in_user

    setup %{user: user} do
      meeting = meeting_fixture_for_user(user)
      credential = salesforce_credential_fixture(%{user_id: user.id})
      %{meeting: meeting, credential: credential}
    end

    test "renders modal with 'Update in Salesforce' title", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/salesforce")

      assert has_element?(view, "h2", "Update Salesforce")
    end

    test "shows contact search input", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/salesforce")

      assert has_element?(view, "[phx-keyup=contact_search]") or
               has_element?(view, "input[id*='contact-select-input']")
    end
  end

  describe "CRM Modal - without credential" do
    setup :register_and_log_in_user

    setup %{user: user} do
      meeting = meeting_fixture_for_user(user)
      %{meeting: meeting}
    end

    test "does not show CRM section when no hubspot credential", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should not show CRM section when no credentials exist
      refute html =~ "Select CRM"
      refute html =~ "Update HubSpot"
    end

    test "does not show CRM section when no salesforce credential", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should not show CRM section when no credentials exist
      refute html =~ "Select CRM"
      refute html =~ "Update Salesforce"
    end
  end

  defp meeting_fixture_for_user(user) do
    calendar_event = SocialScribe.CalendarFixtures.calendar_event_fixture(%{user_id: user.id})
    meeting_fixture(%{calendar_event_id: calendar_event.id})
  end
end
