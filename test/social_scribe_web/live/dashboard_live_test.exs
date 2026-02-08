defmodule SocialScribeWeb.DashboardLiveTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures

  describe "Index" do
    setup :register_and_log_in_user

    test "mounts and shows page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Upcoming Meetings"
    end

    test "displays events when present", %{conn: conn, user: user} do
      credential = user_credential_fixture(%{user_id: user.id})

      _event =
        calendar_event_fixture(%{
          user_id: user.id,
          user_credential_id: credential.id,
          start_time: DateTime.add(DateTime.utc_now(), 1, :hour),
          summary: "Test Meeting"
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Test Meeting"
    end
  end
end
