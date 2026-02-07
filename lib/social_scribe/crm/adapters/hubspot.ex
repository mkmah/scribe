defmodule SocialScribe.Crm.Adapters.Hubspot do
  @moduledoc """
  HubSpot CRM adapter implementing Crm.Behaviour.

  Wraps existing HubSpot API logic with the unified CRM interface.
  Uses Crm.TokenRefresher for token management.
  """

  @behaviour SocialScribe.Crm.Behaviour

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.Crm.Adapters.HubspotFields
  alias SocialScribe.Crm.TokenRefresher

  require Logger

  @base_url "https://api.hubapi.com"

  @impl true
  def provider_name, do: "hubspot"

  @impl true
  def field_mappings, do: HubspotFields.mappings()

  @impl true
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    TokenRefresher.with_token_refresh(credential, __MODULE__, fn cred ->
      body = %{
        query: query,
        limit: 10,
        properties: HubspotFields.contact_properties()
      }

      case Tesla.post(client(cred.token), "/crm/v3/objects/contacts/search", body) do
        {:ok, %Tesla.Env{status: 200, body: %{"results" => results}}} ->
          contacts = Enum.map(results, &HubspotFields.to_contact/1)
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
      properties_param = Enum.join(HubspotFields.contact_properties(), ",")
      url = "/crm/v3/objects/contacts/#{contact_id}?properties=#{properties_param}"

      case Tesla.get(client(cred.token), url) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          {:ok, HubspotFields.to_contact(body)}

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
      # Convert canonical field names to HubSpot field names
      provider_updates = HubspotFields.to_provider_fields(updates)
      body = %{properties: provider_updates}

      case Tesla.patch(client(cred.token), "/crm/v3/objects/contacts/#{contact_id}", body) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          {:ok, HubspotFields.to_contact(body)}

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
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Hubspot.OAuth, [])
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

    case Tesla.post(http_client, "https://api.hubapi.com/oauth/v1/token", body) do
      {:ok, %Tesla.Env{status: 200, body: response}} ->
        attrs = %{
          token: response["access_token"],
          refresh_token: response["refresh_token"],
          expires_at: DateTime.add(DateTime.utc_now(), response["expires_in"], :second)
        }

        SocialScribe.Accounts.update_user_credential(credential, attrs)

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp client(access_token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{access_token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end
end
