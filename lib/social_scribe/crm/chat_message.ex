defmodule SocialScribe.Crm.ChatMessage do
  @moduledoc """
  Schema for chat messages in a conversation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :role, :string
    field :content, :string
    field :metadata, :map, default: %{}

    belongs_to :conversation, SocialScribe.Crm.ChatConversation

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :metadata, :conversation_id])
    |> validate_required([:role, :content, :conversation_id])
    |> validate_inclusion(:role, ["user", "assistant", "system"])
  end
end
