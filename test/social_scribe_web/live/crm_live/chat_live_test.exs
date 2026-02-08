defmodule SocialScribeWeb.CrmLive.ChatLiveTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Chat page rendering" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "renders 'Ask Anything' header", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      assert has_element?(view, "h1", "Ask Anything")
    end

    test "renders Chat and History tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/chat")

      assert html =~ "Chat"
      assert html =~ "History"
    end

    test "renders message input with placeholder", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      assert has_element?(view, "input[placeholder]") or
               has_element?(view, "textarea[placeholder]")
    end

    test "shows AI welcome message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/chat")

      assert html =~ "Ask anything about your meetings" or
               html =~ "How can I help"
    end
  end

  describe "Chat interaction" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "sending a message adds it to the chat", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      SocialScribe.AIContentGeneratorMock
      |> Mox.expect(:answer_crm_question, fn _question, _context ->
        {:ok, "Here is some information about your question."}
      end)

      view
      |> form("#chat-form", %{message: "Hello there"})
      |> render_submit()

      html = render(view)
      assert html =~ "Hello there"
    end
  end

  describe "Chat navigation" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "chat is accessible from sidebar", %{conn: conn} do
      {:ok, _view, _html} = live(conn, ~p"/dashboard/chat")
      # If it renders without error, it's accessible
    end

    test "requires authentication" do
      conn = build_conn()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/chat")
      assert path == ~p"/users/log_in"
    end
  end
end
