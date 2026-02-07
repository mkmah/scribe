defmodule SocialScribe.Repo.Migrations.CreateChatConversations do
  use Ecto.Migration

  def change do
    create table(:chat_conversations) do
      add :title, :string, default: "New Conversation"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_conversations, [:user_id])
  end
end
