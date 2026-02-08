defmodule SocialScribeWeb.MeetingLive.DraftPostFormComponentTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.AutomationsFixtures

  defp meeting_for_user(user) do
    credential = user_credential_fixture(%{user_id: user.id})
    event = calendar_event_fixture(%{user_id: user.id, user_credential_id: credential.id})
    meeting_fixture(%{calendar_event_id: event.id, title: "Draft Post Meeting"})
  end

  defmodule WrapperLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:meeting, session["meeting"])
       |> Phoenix.Component.assign(:automation_result, session["automation_result"])
       |> Phoenix.Component.assign(:automation, session["automation"])
       |> Phoenix.Component.assign(:current_user, session["current_user"])
       |> Phoenix.Component.assign(:patch, session["patch"])}
    end

    def render(assigns) do
      ~H"""
      <.live_component
        module={SocialScribeWeb.MeetingLive.DraftPostFormComponent}
        id={"draft-post-#{@meeting.id}"}
        automation_result={@automation_result}
        automation={@automation}
        meeting={@meeting}
        current_user={@current_user}
        patch={@patch}
      />
      """
    end
  end

  describe "DraftPostFormComponent" do
    setup :register_and_log_in_user

    test "renders draft post form with generated content", %{conn: conn, user: user} do
      meeting = meeting_for_user(user)
      automation = automation_fixture(%{user_id: user.id, platform: :linkedin})

      automation_result =
        automation_result_fixture(%{
          meeting_id: meeting.id,
          automation_id: automation.id,
          generated_content: "Check out our latest insights from the meeting."
        })

      session = %{
        "meeting" => meeting,
        "automation_result" => automation_result,
        "automation" => automation,
        "current_user" => user,
        "patch" => ~p"/dashboard/meetings/#{meeting}"
      }

      {:ok, _view, html} = live_isolated(conn, WrapperLive, session: session)

      assert html =~ "Draft Post"
      assert html =~ "Generate a post based on insights from this meeting"
      assert html =~ "Check out our latest insights from the meeting."
      assert html =~ "draft-post-form"
      assert html =~ "Post"
      assert html =~ "Cancel"
    end

    test "validate updates form on phx-change", %{conn: conn, user: user} do
      meeting = meeting_for_user(user)
      automation = automation_fixture(%{user_id: user.id, platform: :linkedin})

      automation_result =
        automation_result_fixture(%{
          meeting_id: meeting.id,
          automation_id: automation.id,
          generated_content: "Original content"
        })

      session = %{
        "meeting" => meeting,
        "automation_result" => automation_result,
        "automation" => automation,
        "current_user" => user,
        "patch" => ~p"/dashboard/meetings/#{meeting}"
      }

      {:ok, view, _html} = live_isolated(conn, WrapperLive, session: session)

      view
      |> form("form#draft-post-form", %{generated_content: "Updated draft text"})
      |> render_change()

      assert render(view) =~ "Updated draft text"
    end
  end

  describe "DraftPostFormComponent via MeetingLive draft_post" do
    setup :register_and_log_in_user

    test "draft_post page renders component and post error path", %{conn: conn, user: user} do
      meeting = meeting_for_user(user)
      automation = automation_fixture(%{user_id: user.id, platform: :linkedin})

      automation_result =
        automation_result_fixture(%{
          meeting_id: meeting.id,
          automation_id: automation.id,
          generated_content: "Draft from meeting"
        })

      {:ok, view, _html} =
        live(conn, ~p"/dashboard/meetings/#{meeting.id}/draft_post/#{automation_result.id}")

      assert render(view) =~ "Draft Post"
      assert render(view) =~ "Draft from meeting"

      view
      |> form("form#draft-post-form", %{generated_content: "Draft from meeting"})
      |> render_submit()

      # Redirects back to meeting and shows error (no LinkedIn credential)
      assert_patch(view, ~p"/dashboard/meetings/#{meeting}")
      assert render(view) =~ "LinkedIn credential not found"
    end
  end
end
