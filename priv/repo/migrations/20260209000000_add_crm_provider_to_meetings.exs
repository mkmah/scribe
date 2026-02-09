defmodule SocialScribe.Repo.Migrations.AddCrmProviderToMeetings do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      add :crm_provider, :string
      add :crm_contact_id, :string
    end

    create index(:meetings, [:crm_provider])
  end
end
