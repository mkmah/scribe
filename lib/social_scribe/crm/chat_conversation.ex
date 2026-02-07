defmodule SocialScribe.Crm.ChatConversation do
  @moduledoc """
  Schema for chat conversations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_conversations" do
    field :title, :string, default: "New Conversation"

    belongs_to :user, SocialScribe.Accounts.User
    has_many :messages, SocialScribe.Crm.ChatMessage, foreign_key: :conversation_id

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :user_id])
    |> validate_required([:user_id])
    |> set_default_title()
  end

  defp set_default_title(changeset) do
    case get_field(changeset, :title) do
      nil -> put_change(changeset, :title, "New Conversation")
      "" -> put_change(changeset, :title, "New Conversation")
      _ -> changeset
    end
  end
end
