defmodule SocialScribe.Crm.Adapters.Salesforce do
  @moduledoc """
  Salesforce CRM adapter implementing Crm.Behaviour.

  Uses the Salesforce REST API for contact operations.
  Full API implementation will be completed in Phase 3b after OAuth is set up.
  """

  @behaviour SocialScribe.Crm.Behaviour

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.Crm.Adapters.SalesforceFields
  alias SocialScribe.Crm.TokenRefresher

  require Logger

  @sf_api_version "v59.0"

  @impl true
  def provider_name, do: "salesforce"

  @impl true
  def field_mappings, do: SalesforceFields.mappings()

  @impl true
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    TokenRefresher.with_token_refresh(credential, __MODULE__, fn cred ->
      fields = Enum.join(SalesforceFields.contact_fields(), ",")

      sosl_query =
        URI.encode("FIND {#{query}} IN ALL FIELDS RETURNING Contact(Id,#{fields} LIMIT 10)")

      url = "/services/data/#{@sf_api_version}/search/?q=#{sosl_query}"

      case Tesla.get(client(cred), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"searchRecords" => results}}} ->
          contacts = Enum.map(results, &SalesforceFields.to_contact/1)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: 200, body: results}} when is_list(results) ->
          contacts = Enum.map(results, &SalesforceFields.to_contact/1)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @impl true
  def get_contact(%UserCredential{} = credential, contact_id) do
    TokenRefresher.with_token_refresh(credential, __MODULE__, fn cred ->
      fields = Enum.join(SalesforceFields.contact_fields(), ",")
      url = "/services/data/#{@sf_api_version}/sobjects/Contact/#{contact_id}?fields=#{fields}"

      case Tesla.get(client(cred), url) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          {:ok, SalesforceFields.to_contact(body)}

        {:ok, %Tesla.Env{status: 404}} ->
          {:error, :not_found}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @impl true
  def update_contact(%UserCredential{} = credential, contact_id, updates) when is_map(updates) do
    TokenRefresher.with_token_refresh(credential, __MODULE__, fn cred ->
      provider_updates = SalesforceFields.to_provider_fields(updates)
      url = "/services/data/#{@sf_api_version}/sobjects/Contact/#{contact_id}"

      case Tesla.patch(client(cred), url, provider_updates) do
        {:ok, %Tesla.Env{status: status}} when status in [200, 204] ->
          # Salesforce returns 204 on successful update, fetch the updated contact
          get_contact(credential, contact_id)

        {:ok, %Tesla.Env{status: 404}} ->
          {:error, :not_found}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @impl true
  def refresh_token(%UserCredential{} = credential) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Salesforce.OAuth, [])
    client_id = config[:client_id]
    client_secret = config[:client_secret]

    body = %{
      grant_type: "refresh_token",
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: credential.refresh_token
    }

    http_client =
      Tesla.client([
        {Tesla.Middleware.FormUrlencoded,
         encode: &Plug.Conn.Query.encode/1, decode: &Plug.Conn.Query.decode/1},
        Tesla.Middleware.JSON
      ])

    case Tesla.post(http_client, "https://login.salesforce.com/services/oauth2/token", body) do
      {:ok, %Tesla.Env{status: 200, body: response}} ->
        attrs = %{
          token: response["access_token"],
          # Salesforce doesn't always return a new refresh token
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        }

        # instance_url will be stored once the migration is added in Phase 3
        SocialScribe.Accounts.update_user_credential(credential, attrs)

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp client(%UserCredential{} = cred) do
    base_url = get_instance_url(cred) || "https://login.salesforce.com"

    Tesla.client([
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{cred.token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end

  defp get_instance_url(cred) do
    # instance_url field will be added to schema in Phase 3 migration
    # For now, safely access it via Map.get
    Map.get(cred, :instance_url)
  end
end
