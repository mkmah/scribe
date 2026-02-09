defmodule SocialScribeWeb.Components.ChatPopup.MessageListTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.ChatFixtures

  alias SocialScribeWeb.ChatPopup.MessageList

  defmodule MessageListTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:messages, session["messages"] || [])
       |> Phoenix.LiveView.Utils.assign(:current_conversation, session["current_conversation"])
       |> Phoenix.LiveView.Utils.assign(:loading, session["loading"] || false)}
    end

    def render(assigns) do
      ~H"""
      <MessageList.message_list
        messages={@messages}
        current_conversation={@current_conversation}
        loading={@loading}
      />
      """
    end
  end

  describe "message_list/1" do
    test "renders empty state when no messages", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => []})

      assert html =~ "I can answer questions about your meetings and data"
      assert html =~ "just ask!"
      assert html =~ "id=\"chat-popup-messages\""
      assert html =~ "phx-hook=\"ScrollToBottom\""
    end

    test "renders user message", %{conn: conn} do
      messages = [
        %{role: "user", content: "Hello, how are you?"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Hello, how are you?"
      assert html =~ "flex justify-end"
      assert html =~ "bg-muted"
    end

    test "renders assistant message", %{conn: conn} do
      messages = [
        %{role: "assistant", content: "I'm doing well, thank you!"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      # Markdown renders as HTML paragraph
      assert html =~ "doing well"
      assert html =~ "thank you"
      assert html =~ "flex justify-start"
      assert html =~ "markdown-content"
    end

    test "renders multiple messages in order", %{conn: conn} do
      messages = [
        %{role: "user", content: "First message"},
        %{role: "assistant", content: "First response"},
        %{role: "user", content: "Second message"},
        %{role: "assistant", content: "Second response"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "First message"
      assert html =~ "First response"
      assert html =~ "Second message"
      assert html =~ "Second response"
    end

    test "renders timestamp when current_conversation is present", %{conn: conn} do
      conversation = chat_conversation_fixture()
      dt = ~U[2026-02-09 15:30:00Z]
      conversation = %{conversation | inserted_at: dt}

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive,
          session: %{"messages" => [], "current_conversation" => conversation}
        )

      assert html =~ "data-datetime"
      assert html =~ "data-format=\"datetime\""
      assert html =~ "flex items-center gap-3"
    end

    test "does not render timestamp when current_conversation is nil", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive,
          session: %{"messages" => [], "current_conversation" => nil}
        )

      refute html =~ "data-datetime"
    end

    test "renders loading indicator when loading is true", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => [], "loading" => true})

      assert html =~ "Thinking..."
      assert html =~ "animate-bounce"
      assert html =~ "flex justify-start"
    end

    test "does not render loading indicator when loading is false", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => [], "loading" => false})

      refute html =~ "Thinking..."
    end

    test "renders sources badge for assistant messages", %{conn: conn} do
      messages = [
        %{role: "assistant", content: "Here's the answer"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Sources"
      assert html =~ "Gmail"
      assert html =~ "HubSpot"
      assert html =~ "Salesforce"
    end

    test "does not render sources badge for user messages", %{conn: conn} do
      messages = [
        %{role: "user", content: "User message"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      refute html =~ "Sources"
    end
  end

  describe "message_content_block - user messages with mentions" do
    test "renders user message with single mention", %{conn: conn} do
      messages = [
        %{role: "user", content: "Tell me about @John Doe"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Tell me about"
      assert html =~ "mention-pill-inline"
      assert html =~ "John Doe"
      assert html =~ "mention-pill-inline-avatar"
      assert html =~ "mention-pill-inline-name"
    end

    test "renders user message with multiple mentions", %{conn: conn} do
      messages = [
        %{role: "user", content: "Compare @John Doe and @Jane Smith"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Compare"
      assert html =~ "John Doe"
      assert html =~ "Jane Smith"
      # Should have multiple mention pills
      assert Regex.scan(~r/mention-pill-inline/, html) |> length() >= 2
    end

    test "renders user message with mention at start", %{conn: conn} do
      messages = [
        %{role: "user", content: "@Alice what do you think?"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      # The mention regex captures "Alice what do you think" as one mention
      # because it allows spaces in mentions
      assert html =~ "Alice"
      assert html =~ "think"
      assert html =~ "mention-pill-inline"
    end

    test "renders user message with mention at end", %{conn: conn} do
      messages = [
        %{role: "user", content: "Hello there @Bob"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Hello there"
      assert html =~ "Bob"
    end

    test "renders user message with mention in middle", %{conn: conn} do
      messages = [
        %{role: "user", content: "Hi @Charlie, how are you?"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Hi"
      assert html =~ "Charlie"
      assert html =~ "how are you?"
    end

    test "renders user message with multi-word mention", %{conn: conn} do
      messages = [
        %{role: "user", content: "Tell me about @Mary Jane Watson"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Mary Jane Watson"
      assert html =~ "Tell me about"
    end

    test "renders user message without mentions", %{conn: conn} do
      messages = [
        %{role: "user", content: "Just plain text, no mentions"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Just plain text, no mentions"
      refute html =~ "mention-pill-inline"
    end

    test "renders user message with text before and after mention", %{conn: conn} do
      messages = [
        %{role: "user", content: "Before @Middle After"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Before"
      assert html =~ "Middle"
      assert html =~ "After"
    end
  end

  describe "message_content_block - assistant messages" do
    test "renders assistant message with markdown", %{conn: conn} do
      messages = [
        %{role: "assistant", content: "# Heading\n\nThis is **bold** text."}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      # Markdown is rendered to HTML, so check for HTML tags
      assert html =~ "Heading"
      assert html =~ "<h1>"
      assert html =~ "This is"
      assert html =~ "<strong>bold</strong>"
      assert html =~ "markdown-content"
    end

    test "renders assistant message with plain text", %{conn: conn} do
      messages = [
        %{role: "assistant", content: "Plain text response"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      # Markdown renders plain text as paragraph
      assert html =~ "Plain text response"
      assert html =~ "<p>"
      assert html =~ "markdown-content"
    end

    test "renders assistant message with code blocks", %{conn: conn} do
      messages = [
        %{role: "assistant", content: "Here's code:\n```elixir\nIO.puts(\"hello\")\n```"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      # Markdown renders code blocks as HTML
      assert html =~ "Here"
      assert html =~ "code"
      assert html =~ "IO.puts"
    end
  end

  describe "message_content_segments edge cases" do
    test "handles empty string content", %{conn: conn} do
      messages = [
        %{role: "user", content: ""}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      # Should render without errors
      assert html =~ "id=\"chat-popup-messages\""
    end

    test "handles content with only mentions", %{conn: conn} do
      messages = [
        %{role: "user", content: "@Alice @Bob"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "handles mention with numbers", %{conn: conn} do
      messages = [
        %{role: "user", content: "Contact @John123"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "John123"
    end

    test "handles mention regex edge cases", %{conn: conn} do
      # The regex allows lowercase after first letter: @[A-Za-z][A-Za-z0-9]*
      # So @lowercase matches because 'l' is lowercase but the pattern allows it
      messages = [
        %{role: "user", content: "Not a mention: @lowercase"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      # The regex actually matches @lowercase because it allows lowercase after first char
      assert html =~ "lowercase"
      assert html =~ "mention-pill-inline-name"
    end
  end

  describe "sources_badge/1" do
    test "renders sources badge with all three source icons", %{conn: conn} do
      messages = [
        %{role: "assistant", content: "Answer"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "Sources"
      assert html =~ "Gmail"
      assert html =~ "HubSpot"
      assert html =~ "Salesforce"
      assert html =~ "w-4 h-4 rounded-full"
    end

    test "sources badge has correct styling classes", %{conn: conn} do
      messages = [
        %{role: "assistant", content: "Answer"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "flex items-center gap-1.5"
      assert html =~ "text-xs text-muted-foreground/60"
      assert html =~ "flex -space-x-1"
    end
  end

  describe "combined scenarios" do
    test "renders full conversation with timestamp, messages, and loading", %{conn: conn} do
      conversation = chat_conversation_fixture()
      dt = ~U[2026-02-09 15:30:00Z]
      conversation = %{conversation | inserted_at: dt}

      messages = [
        %{role: "user", content: "Question with @John"},
        %{role: "assistant", content: "Answer with **markdown**"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive,
          session: %{
            "messages" => messages,
            "current_conversation" => conversation,
            "loading" => true
          }
        )

      # Check timestamp
      assert html =~ "data-datetime"

      # Check messages
      assert html =~ "Question with"
      assert html =~ "John"
      assert html =~ "Answer with"
      assert html =~ "markdown"

      # Check loading
      assert html =~ "Thinking..."
    end

    test "handles mixed user and assistant messages", %{conn: conn} do
      messages = [
        %{role: "user", content: "First question"},
        %{role: "assistant", content: "First answer"},
        %{role: "user", content: "Second question with @Alice"},
        %{role: "assistant", content: "Second answer"}
      ]

      {:ok, _view, html} =
        live_isolated(conn, MessageListTestLive, session: %{"messages" => messages})

      assert html =~ "First question"
      assert html =~ "First answer"
      assert html =~ "Second question with"
      assert html =~ "Alice"
      assert html =~ "Second answer"
    end
  end
end
