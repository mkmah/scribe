defmodule SocialScribe.ChatFixtures do
  @moduledoc """
  Test helpers for creating chat entities.
  """

  import SocialScribe.AccountsFixtures

  @doc """
  Generate a chat conversation.
  """
  def chat_conversation_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()

    {:ok, conversation} =
      SocialScribe.Crm.Chat.create_conversation(%{
        user_id: user.id,
        title: attrs[:title] || "Test Conversation"
      })

    conversation
  end

  @doc """
  Generate a chat message.
  """
  def chat_message_fixture(conversation, attrs \\ %{}) do
    {:ok, message} =
      SocialScribe.Crm.Chat.add_message(conversation.id, %{
        role: attrs[:role] || "user",
        content: attrs[:content] || "Test message",
        metadata: attrs[:metadata] || %{}
      })

    message
  end
end
