defmodule SocialScribeWeb.MeetingLive.CrmAssociationTest do
  use SocialScribeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.BotsFixtures
  import SocialScribe.MeetingsFixtures

  describe "CRM Association UI" do
    setup :register_and_log_in_user

    test "shows CRM selection buttons when no CRM is associated", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should show selection buttons for both CRMs
      assert html =~ "Use HubSpot"
      assert html =~ "Use Salesforce"
      refute html =~ "Update HubSpot"
      refute html =~ "Update Salesforce"
    end

    test "shows Update button for associated CRM", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: "hubspot"})
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should show Update button for associated CRM
      assert html =~ "Update HubSpot"
      assert html =~ "Change CRM"
      refute html =~ "Update Salesforce"
    end

    test "shows Change CRM option when multiple CRMs connected and one is associated", %{
      conn: conn,
      user: user
    } do
      meeting = meeting_for_user(user, %{crm_provider: "hubspot"})
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "Change CRM"
    end

    test "does not show Change CRM when only one CRM is connected", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: "hubspot"})
      hubspot_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "Update HubSpot"
      refute html =~ "Change CRM"
    end

    test "allows user to set CRM provider", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Click to set HubSpot as provider
      html = render_click(view, "set_crm_provider", %{"provider" => "hubspot"})

      # Should update UI to show Update button
      assert html =~ "Update HubSpot"
      assert html =~ "Change CRM"
      refute html =~ "Use HubSpot"

      # Verify meeting was updated in database
      updated_meeting = SocialScribe.Meetings.get_meeting!(meeting.id)
      assert updated_meeting.crm_provider == "hubspot"
    end

    test "allows user to change CRM provider", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: "hubspot"})
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Click Change CRM button
      html = render_click(view, "show_crm_selector", %{})

      # Should show selection buttons
      assert html =~ "Use HubSpot"
      assert html =~ "Use Salesforce"

      # Select Salesforce
      html = render_click(view, "set_crm_provider", %{"provider" => "salesforce"})

      # Should update to show Salesforce
      assert html =~ "Update Salesforce"
      assert html =~ "Change CRM"

      # Verify meeting was updated in database
      updated_meeting = SocialScribe.Meetings.get_meeting!(meeting.id)
      assert updated_meeting.crm_provider == "salesforce"
    end

    test "shows flash message when CRM provider is set", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})
      hubspot_credential_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      html = render_click(view, "set_crm_provider", %{"provider" => "hubspot"})

      assert html =~ "CRM provider set to HubSpot"
    end

    test "handles error when meeting doesn't exist", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})
      hubspot_credential_fixture(%{user_id: user.id})

      # Delete the meeting to cause mount to redirect
      SocialScribe.Repo.delete(meeting)

      # Mount should redirect when meeting doesn't exist
      # LiveView returns {:error, {:redirect, ...}} when redirecting from mount
      assert {:error,
              {:redirect,
               %{to: "/dashboard/meetings", flash: %{"danger" => "Meeting not found."}}}} =
               live(conn, ~p"/dashboard/meetings/#{meeting.id}")
    end

    test "does not show CRM buttons when user has no CRM credentials", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "Update HubSpot"
      refute html =~ "Update Salesforce"
      refute html =~ "Use HubSpot"
      refute html =~ "Use Salesforce"
    end

    test "shows only connected CRM buttons in selection", %{conn: conn, user: user} do
      # Only connect HubSpot, not Salesforce
      hubspot_credential_fixture(%{user_id: user.id})

      # Create meeting after credential to ensure crm_provider is nil
      meeting = meeting_for_user(user, %{crm_provider: nil})

      # Reload meeting to ensure crm_provider is nil
      meeting = SocialScribe.Repo.reload!(meeting)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      html = render(view)

      # Should only show HubSpot option (as "Use HubSpot" when no provider is set)
      assert html =~ "Use HubSpot"
      refute html =~ "Use Salesforce"
    end

    test "handles invalid provider string gracefully", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})
      hubspot_credential_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Try to set an invalid provider string
      html = render_click(view, "set_crm_provider", %{"provider" => "invalid_crm_provider"})

      # Should still update the meeting (no validation on crm_provider field)
      # Registry.provider_label will capitalize it
      updated_meeting = SocialScribe.Meetings.get_meeting!(meeting.id)
      assert updated_meeting.crm_provider == "invalid_crm_provider"

      # Flash message should show capitalized version
      assert html =~ "CRM provider set to Invalid_crm_provider"
    end

    test "handles error when update fails", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})
      hubspot_credential_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Delete the meeting to cause update to fail
      SocialScribe.Repo.delete(meeting)

      # Try to set provider - should handle error gracefully
      html = render_click(view, "set_crm_provider", %{"provider" => "hubspot"})

      # Should show error flash
      assert html =~ "Failed to set CRM provider"
    end
  end

  describe "Application config override" do
    setup :register_and_log_in_user

    test "build_crm_credentials respects Application config when set to specific adapter", %{
      conn: conn,
      user: user
    } do
      # Connect both CRMs
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      meeting = meeting_for_user(user, %{crm_provider: nil})

      # Set Application config to HubSpot adapter
      Application.put_env(:social_scribe, :crm_api, SocialScribe.Crm.Adapters.Hubspot)

      on_exit(fn ->
        Application.delete_env(:social_scribe, :crm_api)
      end)

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should only show HubSpot (filtered by config)
      assert html =~ "Use HubSpot"
      refute html =~ "Use Salesforce"
    end

    test "build_crm_credentials shows all CRMs when config is nil", %{conn: conn, user: user} do
      # Connect both CRMs
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      meeting = meeting_for_user(user, %{crm_provider: nil})

      # Ensure config is nil (default in test)
      Application.delete_env(:social_scribe, :crm_api)

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should show both CRMs
      assert html =~ "Use HubSpot"
      assert html =~ "Use Salesforce"
    end

    test "build_crm_credentials shows all CRMs when config is Mock adapter", %{
      conn: conn,
      user: user
    } do
      # Connect both CRMs
      hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential_fixture(%{user_id: user.id})

      meeting = meeting_for_user(user, %{crm_provider: nil})

      # Set config to Mock adapter (not in registry)
      Application.put_env(:social_scribe, :crm_api, SocialScribe.CrmApiMock)

      on_exit(fn ->
        Application.delete_env(:social_scribe, :crm_api)
      end)

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Should show all CRMs (Mock is not in known_adapters)
      assert html =~ "Use HubSpot"
      assert html =~ "Use Salesforce"
    end
  end

  describe "CRM Modal Integration" do
    setup :register_and_log_in_user

    test "opens CRM modal with associated provider", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: "hubspot"})
      hubspot_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} =
        live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/hubspot")

      # Should show CRM modal
      assert html =~ "Update HubSpot"
    end

    test "allows opening CRM modal after setting provider", %{conn: conn, user: user} do
      meeting = meeting_for_user(user, %{crm_provider: nil})
      hubspot_credential_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Set provider
      render_click(view, "set_crm_provider", %{"provider" => "hubspot"})

      # Navigate to CRM modal
      {:ok, _view, html} =
        live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/hubspot")

      assert html =~ "Update HubSpot"
    end
  end

  defp meeting_for_user(user, attrs) do
    credential = user_credential_fixture(%{user_id: user.id})
    event = calendar_event_fixture(%{user_id: user.id, user_credential_id: credential.id})
    recall_bot = recall_bot_fixture(%{calendar_event_id: event.id, user_id: user.id})

    meeting_fixture(
      Map.merge(
        %{
          calendar_event_id: event.id,
          recall_bot_id: recall_bot.id,
          title: "Test Meeting"
        },
        attrs
      )
    )
  end
end
