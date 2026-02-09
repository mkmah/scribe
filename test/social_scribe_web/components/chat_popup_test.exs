defmodule SocialScribeWeb.Components.ChatPopupTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.ChatFixtures

  defmodule WrapperLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:current_user, session["current_user"])}
    end

    def render(assigns) do
      ~H"""
      <.live_component module={SocialScribeWeb.ChatPopup} id="chat-popup" current_user={@current_user} />
      """
    end
  end

  describe "ChatPopup" do
    setup :register_and_log_in_user

    test "mounts closed by default", %{conn: conn, user: user} do
      {:ok, _view, html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      assert html =~ "Open chat"
      assert html =~ "chat-panel"
    end

    test "toggle opens panel and shows Ask Anything", %{conn: conn, user: user} do
      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view
      |> element("button[phx-click=\"toggle_chat\"]")
      |> render_click()

      assert render(view) =~ "Ask Anything"
      assert render(view) =~ "Chat"
      assert render(view) =~ "History"
    end

    test "close_chat closes panel", %{conn: conn, user: user} do
      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view
      |> element("button[phx-click=\"toggle_chat\"]")
      |> render_click()

      assert render(view) =~ "Ask Anything"

      view
      |> element("button[title=\"Close\"]")
      |> render_click()

      # Panel is hidden (pointer-events-none when closed)
      html = render(view)
      assert html =~ "pointer-events-none"
    end

    test "switch_tab to history shows History tab", %{conn: conn, user: user} do
      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("button[phx-value-tab=\"history\"]")
      |> render_click()

      assert render(view) =~ "No conversations yet"
    end

    test "new_chat clears conversation", %{conn: conn, user: user} do
      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()
      view |> element("button[title=\"New chat\"]") |> render_click()
      assert render(view) =~ "Ask Anything"
    end

    test "load_conversation loads messages", %{conn: conn, user: user} do
      conv = chat_conversation_fixture(%{user: user})
      chat_message_fixture(conv, %{role: "user", content: "Hello"})
      chat_message_fixture(conv, %{role: "assistant", content: "Hi @John Doe"})

      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("button[phx-value-tab=\"history\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"load_conversation\"][phx-value-id=\"#{conv.id}\"]")
      |> render_click()

      html = render(view)
      assert html =~ "Hello"
      assert html =~ "Hi"
      assert html =~ "John Doe"
    end

    test "send_message with empty string does nothing", %{conn: conn, user: user} do
      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("form[phx-submit=\"send_message\"]")
      |> render_submit(%{message: ""})

      assert render(view) =~ "Ask Anything"
    end

    test "send_message with whitespace-only trims and does nothing", %{conn: conn, user: user} do
      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("form[phx-submit=\"send_message\"]")
      |> render_submit(%{message: "   \n\t  "})

      assert render(view) =~ "Ask Anything"
    end

    test "send_message creates conversation and shows messages", %{conn: conn, user: user} do
      SocialScribe.AIContentGeneratorMock
      |> Mox.stub(:answer_crm_question, fn _q, _ctx -> {:ok, "Here are your meetings."} end)

      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("form[phx-submit=\"send_message\"]")
      |> render_submit(%{message: "What meetings do I have?"})

      html = render(view)
      assert html =~ "What meetings do I have?"
      assert html =~ "Here are your meetings"
    end

    test "send_message with existing conversation uses same conversation", %{
      conn: conn,
      user: user
    } do
      SocialScribe.AIContentGeneratorMock
      |> Mox.stub(:answer_crm_question, fn _q, _ctx ->
        {:ok, "Follow-up answer."}
      end)

      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("form[phx-submit=\"send_message\"]")
      |> render_submit(%{message: "First question"})

      view
      |> element("form[phx-submit=\"send_message\"]")
      |> render_submit(%{message: "Second question"})

      html = render(view)
      assert html =~ "First question"
      assert html =~ "Second question"
      assert html =~ "Follow-up answer"
    end

    test "send_message when AI returns error still shows fallback response", %{
      conn: conn,
      user: user
    } do
      SocialScribe.AIContentGeneratorMock
      |> Mox.stub(:answer_crm_question, fn _q, _ctx -> {:error, :stubbed} end)

      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("form[phx-submit=\"send_message\"]")
      |> render_submit(%{message: "Test"})

      html = render(view)
      assert html =~ "Ask Anything"
      assert html =~ "try again"
    end

    test "send_message when Chat.ask returns error clears loading", %{conn: conn, user: user} do
      Application.put_env(:social_scribe_web, :chat_ask_fn, fn _cid, _msg, _uid ->
        {:error, :test}
      end)

      on_exit(fn ->
        Application.delete_env(:social_scribe_web, :chat_ask_fn)
      end)

      {:ok, view, _html} =
        live_isolated(conn, WrapperLive, session: %{"current_user" => user})

      view |> element("button[phx-click=\"toggle_chat\"]") |> render_click()

      view
      |> element("form[phx-submit=\"send_message\"]")
      |> render_submit(%{message: "Test"})

      html = render(view)
      assert html =~ "Ask Anything"
      # Loading should be cleared (no "Thinking..." stuck)
      refute html =~ "Thinking..."
    end
  end
end
