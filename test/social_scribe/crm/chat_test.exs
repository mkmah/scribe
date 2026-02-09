defmodule SocialScribe.Crm.ChatTest do
  use SocialScribe.DataCase

  alias SocialScribe.Crm.Chat

  import SocialScribe.AccountsFixtures
  import Mox

  setup :verify_on_exit!

  describe "parse_mentions/1" do
    test "extracts single @Name mention" do
      result = Chat.parse_mentions("Tell me about @John Doe")
      assert result == ["John Doe"]
    end

    test "extracts multiple @Name mentions" do
      result = Chat.parse_mentions("Compare @John Doe and @Jane Smith")
      assert length(result) == 2
      assert "John Doe" in result
      assert "Jane Smith" in result
    end

    test "handles @First Last with space" do
      result = Chat.parse_mentions("What about @Mary Jane Watson?")
      assert result == ["Mary Jane Watson"]
    end

    test "returns empty list when no mentions" do
      result = Chat.parse_mentions("No mentions here")
      assert result == []
    end

    test "handles @Name at start, middle, and end of text" do
      result = Chat.parse_mentions("@Alice talked to @Bob about @Charlie")
      assert length(result) == 3
    end
  end

  describe "create_conversation/1" do
    test "creates a conversation for a user" do
      user = user_fixture()

      assert {:ok, conversation} =
               Chat.create_conversation(%{user_id: user.id, title: "Test Chat"})

      assert conversation.user_id == user.id
      assert conversation.title == "Test Chat"
    end

    test "sets default title" do
      user = user_fixture()

      assert {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      assert conversation.title == "New Conversation"
    end
  end

  describe "list_conversations/1" do
    test "returns conversations for user ordered by most recent" do
      user = user_fixture()

      {:ok, _conv1} = Chat.create_conversation(%{user_id: user.id, title: "First"})
      {:ok, conv2} = Chat.create_conversation(%{user_id: user.id, title: "Second"})

      conversations = Chat.list_conversations(user.id)

      assert length(conversations) == 2
      # Most recent first
      assert hd(conversations).id == conv2.id
    end

    test "returns empty list when no conversations" do
      user = user_fixture()

      assert [] == Chat.list_conversations(user.id)
    end
  end

  describe "add_message/2" do
    test "creates a user message in conversation" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      assert {:ok, message} =
               Chat.add_message(conversation.id, %{
                 role: "user",
                 content: "Hello world"
               })

      assert message.role == "user"
      assert message.content == "Hello world"
      assert message.conversation_id == conversation.id
    end

    test "creates an assistant message in conversation" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      assert {:ok, message} =
               Chat.add_message(conversation.id, %{
                 role: "assistant",
                 content: "Hi! How can I help?"
               })

      assert message.role == "assistant"
    end

    test "stores metadata (sources, contacts)" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      metadata = %{"sources" => ["hubspot"], "contacts" => ["John Doe"]}

      assert {:ok, message} =
               Chat.add_message(conversation.id, %{
                 role: "assistant",
                 content: "Here's what I found",
                 metadata: metadata
               })

      assert message.metadata == metadata
    end
  end

  describe "get_conversation_messages/1" do
    test "returns messages ordered by inserted_at" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      {:ok, _msg1} =
        Chat.add_message(conversation.id, %{role: "user", content: "First"})

      {:ok, _msg2} =
        Chat.add_message(conversation.id, %{role: "assistant", content: "Second"})

      messages = Chat.get_conversation_messages(conversation.id)

      assert length(messages) == 2
      assert hd(messages).content == "First"
      assert List.last(messages).content == "Second"
    end

    test "returns empty list for new conversation" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      assert [] == Chat.get_conversation_messages(conversation.id)
    end
  end

  describe "ask/3" do
    setup do
      # Ensure CRM API mock is configured
      Application.put_env(:social_scribe, :crm_api, SocialScribe.CrmApiMock)
      :ok
    end

    test "parses mentions, fetches contact, calls AI, persists messages" do
      user = user_fixture()
      _cred = hubspot_credential_fixture(%{user_id: user.id})
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      SocialScribe.CrmApiMock
      |> expect(:search_contacts, fn _cred, "John Doe" ->
        {:ok,
         [
           SocialScribe.Crm.Contact.new(%{
             id: "123",
             first_name: "John",
             last_name: "Doe",
             email: "john@example.com",
             company: "Acme Corp",
             provider: "hubspot"
           })
         ]}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:answer_crm_question, fn _question, _context ->
        {:ok, "John Doe works at Acme Corp as a senior engineer."}
      end)

      assert {:ok, %{user_message: user_msg, assistant_message: assistant_msg}} =
               Chat.ask(conversation.id, "Tell me about @John Doe", user.id)

      assert user_msg.role == "user"
      assert user_msg.content == "Tell me about @John Doe"
      assert assistant_msg.role == "assistant"
      assert assistant_msg.content =~ "Acme Corp"
    end

    test "handles question with no mentions" do
      user = user_fixture()
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      SocialScribe.AIContentGeneratorMock
      |> expect(:answer_crm_question, fn _question, _context ->
        {:ok, "I can help you with CRM questions. Try mentioning a contact with @Name."}
      end)

      assert {:ok, %{assistant_message: msg}} =
               Chat.ask(conversation.id, "What can you do?", user.id)

      assert msg.content =~ "CRM"
    end

    test "returns error when CRM API fails" do
      user = user_fixture()
      _cred = hubspot_credential_fixture(%{user_id: user.id})
      {:ok, conversation} = Chat.create_conversation(%{user_id: user.id})

      SocialScribe.CrmApiMock
      |> expect(:search_contacts, fn _cred, _query ->
        {:error, {:api_error, 500, "Internal Server Error"}}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:answer_crm_question, fn _question, _context ->
        {:ok, "I couldn't fetch the contact data, but based on what I know..."}
      end)

      assert {:ok, _result} = Chat.ask(conversation.id, "Tell me about @Missing Contact", user.id)
    end
  end
end
