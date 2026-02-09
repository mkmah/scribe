defmodule SocialScribe.Workers.CrmTokenRefresher do
  @moduledoc """
  Oban worker that proactively refreshes OAuth tokens before they expire
  for ALL registered CRM providers.

  Runs periodically and refreshes tokens expiring within 10 minutes.
  Unified token refresher for all CRM providers.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias SocialScribe.Repo
  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.Crm.Registry
  alias SocialScribe.Crm.TokenRefresher

  import Ecto.Query

  require Logger

  @refresh_threshold_minutes 10

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Running proactive CRM token refresh check...")

    providers = Registry.crm_providers()
    expiring_credentials = get_expiring_credentials(providers)

    case expiring_credentials do
      [] ->
        Logger.debug("No CRM tokens expiring soon")
        :ok

      credentials ->
        Logger.info("Found #{length(credentials)} CRM token(s) expiring soon, refreshing...")

        refresh_all(credentials)
    end
  end

  defp get_expiring_credentials(providers) do
    threshold = DateTime.add(DateTime.utc_now(), @refresh_threshold_minutes, :minute)

    from(c in UserCredential,
      where: c.provider in ^providers,
      where: c.expires_at < ^threshold,
      where: not is_nil(c.refresh_token)
    )
    |> Repo.all()
  end

  defp refresh_all(credentials) do
    Enum.each(credentials, fn credential ->
      case Registry.adapter_for(credential.provider) do
        {:ok, adapter} ->
          case TokenRefresher.ensure_valid_token(credential, adapter) do
            {:ok, _updated} ->
              Logger.info(
                "Refreshed #{credential.provider} token for credential #{credential.id}"
              )

            {:error, reason} ->
              Logger.error(
                "Failed to refresh #{credential.provider} token for credential #{credential.id}: #{inspect(reason)}"
              )
          end

        {:error, _} ->
          Logger.warning(
            "Unknown CRM provider #{credential.provider} for credential #{credential.id}"
          )
      end
    end)

    :ok
  end
end
