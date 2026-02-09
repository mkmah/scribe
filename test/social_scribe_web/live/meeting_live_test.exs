defmodule SocialScribeWeb.MeetingLiveTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.AutomationsFixtures

  defp meeting_for_user(user) do
    credential = user_credential_fixture(%{user_id: user.id})
    # Ensure event has a user_credential_id
    event = calendar_event_fixture(%{user_id: user.id, user_credential_id: credential.id})
    meeting_fixture(%{calendar_event_id: event.id, title: "My Test Meeting"})
  end

  defp meeting_with_transcript(user) do
    meeting = meeting_for_user(user)

    transcript_content = %{
      "data" => [
        %{
          "participant" => %{"name" => "Alice"},
          "words" => [%{"text" => "Hello"}, %{"text" => "world"}]
        }
      ]
    }

    meeting_transcript_fixture(%{meeting_id: meeting.id, content: transcript_content})
    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end

  describe "Index" do
    setup :register_and_log_in_user

    test "mounts and shows past meetings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings")
      assert html =~ "Past Meetings"
    end

    test "lists user meetings", %{conn: conn, user: user} do
      meeting = meeting_for_user(user)
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings")
      assert html =~ meeting.title
    end
  end

  describe "Show" do
    setup :register_and_log_in_user

    test "mounts meeting show", %{conn: conn, user: user} do
      meeting = meeting_for_user(user)
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")
      assert html =~ meeting.title
      assert html =~ "Back to Meetings"
    end

    test "renders transcript when available", %{conn: conn, user: user} do
      meeting = meeting_with_transcript(user)
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "Hello"
      assert html =~ "world"
      assert html =~ "Alice"
    end

    test "shows regenerate button when automations exist", %{conn: conn, user: user} do
      meeting = meeting_for_user(user)
      automation_fixture(%{user_id: user.id, is_active: true})

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert has_element?(view, "button", "Generate Posts")
    end

    test "navigates to Salesforce modal", %{conn: conn, user: user} do
      meeting = meeting_for_user(user)
      # Need a Salesforce credential for the button to appear or work?
      # The show.ex checks for registered providers.
      # Let's just try accessing the route directly.

      # It might show an error or the modal depending on credential existence.
      # Based on show.ex, it sets :crm_modal_provider to "salesforce".
      # The modal wrapper id is "crm-modal-salesforce-wrapper"

      # If no credential, it might differ. But let's check for the wrapper if possible.
      # Actually, checking `hubspot_modal_test.exs`, navigation without credential might redirect or fail to show content.
      # Let's add a credential first.

      _sf_cred = salesforce_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")
      # When no CRM is associated, shows "Use Salesforce" button
      assert html =~ "Use Salesforce"

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/crm/salesforce")
      assert has_element?(view, "#crm-modal-salesforce-wrapper")
    end
  end
end
