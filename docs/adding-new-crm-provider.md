# Adding a New CRM Provider

This guide explains how to add a new CRM (Customer Relationship Management) provider to Social Scribe. The application supports HubSpot and Salesforce out of the box, and the architecture is designed to make adding additional CRMs straightforward.

Adding a new CRM requires four main components:
1. An adapter module that implements the CRM behaviour
2. A field mapping module for translating between canonical and provider-specific field names
3. A Ueberauth strategy for OAuth authentication
4. Configuration entries for OAuth credentials

This guide uses Pipedrive as an example, but the same pattern applies to any CRM.

---

## Part 1: Understanding the Architecture

Before diving into the implementation, here is how the CRM system is organized:

```
lib/social_scribe/crm/
  behaviour.ex              # Defines the interface all CRM adapters must implement
  registry.ex               # Maps provider strings to adapter modules
  token_refresher.ex        # Generic token refresh logic used by all adapters
  contact.ex                # Unified contact struct used across providers
  adapters/
    hubspot.ex              # HubSpot adapter
    hubspot_fields.ex       # Field mappings for HubSpot
    salesforce.ex           # Salesforce adapter
    salesforce_fields.ex    # Field mappings for Salesforce
```

The `behaviour.ex` file defines six callbacks that every adapter must implement:

- `search_contacts/2` - Search for contacts by query string
- `get_contact/2` - Fetch a single contact by ID
- `update_contact/3` - Update a contact with new field values
- `refresh_token/1` - Refresh an expired OAuth token
- `provider_name/0` - Return the provider string (e.g., "pipedrive")
- `field_mappings/0` - Return the list of field mappings

---

## Part 2: Create the Field Mapping Module

Start by creating the field mapping module. This defines how your CRM's field names map to the canonical field names used throughout Social Scribe.

Create `lib/social_scribe/crm/adapters/pipedrive_fields.ex`:

```elixir
defmodule SocialScribe.Crm.Adapters.PipedriveFields do
  @moduledoc """
  Field mapping between canonical and Pipedrive field names.
  Provides conversion utilities between Crm.Contact and Pipedrive API formats.
  """

  alias SocialScribe.Crm.Contact

  @mappings [
    %{canonical: "first_name", provider: "first_name", label: "First Name"},
    %{canonical: "last_name", provider: "last_name", label: "Last Name"},
    %{canonical: "email", provider: "email", label: "Email"},
    %{canonical: "phone", provider: "phone", label: "Phone"},
    %{canonical: "company", provider: "org_name", label: "Company"},
    %{canonical: "job_title", provider: "job_title", label: "Job Title"},
    %{canonical: "address", provider: "address", label: "Address"},
    %{canonical: "city", provider: "city", label: "City"},
    %{canonical: "state", provider: "state", label: "State"},
    %{canonical: "zip", provider: "postal_code", label: "ZIP Code"},
    %{canonical: "country", provider: "country", label: "Country"}
  ]

  @doc """
  Returns the full list of field mappings.
  """
  def mappings, do: @mappings

  @doc """
  Returns the list of Pipedrive field names to request from the API.
  """
  def contact_fields do
    Enum.map(@mappings, & &1.provider)
  end

  @doc """
  Converts a Pipedrive API response into a Crm.Contact struct.
  """
  @spec to_contact(map()) :: Contact.t()
  def to_contact(%{"id" => id} = response) do
    attrs =
      @mappings
      |> Enum.reduce(%{id: to_string(id), provider: "pipedrive", provider_data: response}, fn mapping, acc ->
        value = Map.get(response, mapping.provider)
        Map.put(acc, String.to_atom(mapping.canonical), value)
      end)

    Contact.new(attrs)
  end

  def to_contact(%{} = response) do
    Contact.new(%{provider: "pipedrive", provider_data: response})
  end

  @doc """
  Converts a map of canonical field names to Pipedrive provider field names.
  Skips fields that do not have a mapping.
  """
  @spec to_provider_fields(map()) :: map()
  def to_provider_fields(canonical_fields) when is_map(canonical_fields) do
    canonical_to_provider = Map.new(@mappings, fn m -> {m.canonical, m.provider} end)

    canonical_fields
    |> Enum.reduce(%{}, fn {canonical, value}, acc ->
      case Map.get(canonical_to_provider, canonical) do
        nil -> acc
        provider_field -> Map.put(acc, provider_field, value)
      end
    end)
  end
end
```

The key things to understand here:

- The `@mappings` list connects your CRM's field names (under `provider`) to the standard field names Social Scribe uses (under `canonical`)
- The `to_contact/1` function converts API responses to the unified `Crm.Contact` struct
- The `to_provider_fields/1` function does the reverse: it converts canonical field names back to provider-specific names when updating contacts

---

## Part 3: Create the CRM Adapter

Now create the main adapter module at `lib/social_scribe/crm/adapters/pipedrive.ex`:

```elixir
defmodule SocialScribe.Crm.Adapters.Pipedrive do
  @moduledoc """
  Pipedrive CRM adapter implementing Crm.Behaviour.
  """

  @behaviour SocialScribe.Crm.Behaviour

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.Crm.Adapters.PipedriveFields
  alias SocialScribe.Crm.TokenRefresher

  require Logger

  @base_url "https://api.pipedrive.com/v1"

  @impl true
  def provider_name, do: "pipedrive"

  @impl true
  def field_mappings, do: PipedriveFields.mappings()

  @impl true
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    TokenRefresher.with_token_refresh(credential, __MODULE__, fn cred ->
      # Pipedrive uses a different search endpoint structure
      url = "/persons/search?term=#{URI.encode(query)}&limit=10"

      case Tesla.get(client(cred.token), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"data" => %{"items" => items}}}} when is_list(items) ->
          contacts = Enum.map(items, fn %{"item" => item} -> PipedriveFields.to_contact(item) end)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: 200, body: %{"data" => nil}}} ->
          {:ok, []}

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
      url = "/persons/#{contact_id}"

      case Tesla.get(client(cred.token), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"data" => data}}} ->
          {:ok, PipedriveFields.to_contact(data)}

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
      provider_updates = PipedriveFields.to_provider_fields(updates)
      url = "/persons/#{contact_id}"

      case Tesla.put(client(cred.token), url, provider_updates) do
        {:ok, %Tesla.Env{status: 200, body: %{"data" => data}}} ->
          {:ok, PipedriveFields.to_contact(data)}

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
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Pipedrive.OAuth, [])
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

    case Tesla.post(http_client, "https://oauth.pipedrive.com/oauth/token", body) do
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
```

Notice how every function that makes API calls wraps the logic in `TokenRefresher.with_token_refresh/3`. This helper automatically checks if the token is expired, refreshes it if needed, and retries the call on 401 errors.

---

## Part 4: Register the Adapter

Update `lib/social_scribe/crm/registry.ex` to include your new provider:

```elixir
defmodule SocialScribe.Crm.Registry do
  @moduledoc """
  Maps CRM provider strings to their adapter modules.
  Single source of truth for all registered CRM providers.
  """

  @providers %{
    "hubspot" => SocialScribe.Crm.Adapters.Hubspot,
    "salesforce" => SocialScribe.Crm.Adapters.Salesforce,
    "pipedrive" => SocialScribe.Crm.Adapters.Pipedrive  # Add this line
  }

  @labels %{
    "hubspot" => "HubSpot",
    "salesforce" => "Salesforce",
    "pipedrive" => "Pipedrive"  # Add this line
  }

  # ... rest of the module stays the same
end
```

---

## Part 5: Create the Ueberauth Strategy

The OAuth flow requires a Ueberauth strategy. Create two files:

First, the OAuth module at `lib/ueberauth/strategy/pipedrive/oauth.ex`:

```elixir
defmodule Ueberauth.Strategy.Pipedrive.OAuth do
  @moduledoc """
  OAuth2 for Pipedrive.
  """

  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://api.pipedrive.com",
    authorize_url: "https://oauth.pipedrive.com/oauth/authorize",
    token_url: "https://oauth.pipedrive.com/oauth/token"
  ]

  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    OAuth2.Client.new(opts)
  end

  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  def get_access_token(params \\ [], opts \\ []) do
    case opts |> client() |> OAuth2.Client.get_token(params) do
      {:ok, %OAuth2.Client{token: %OAuth2.AccessToken{} = token}} ->
        {:ok, token}

      {:error, %OAuth2.Response{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {error, description}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"error", to_string(reason)}}
    end
  end

  # OAuth2.Strategy callbacks

  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
```

Then the main strategy at `lib/ueberauth/strategy/pipedrive.ex`:

```elixir
defmodule Ueberauth.Strategy.Pipedrive do
  @moduledoc """
  Pipedrive Strategy for Ueberauth.
  """

  use Ueberauth.Strategy,
    uid_field: :id,
    default_scope: "contacts:read contacts:write",
    oauth2_module: Ueberauth.Strategy.Pipedrive.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts =
      [scope: scopes, redirect_uri: callback_url(conn)]
      |> with_state_param(conn)

    redirect!(conn, Ueberauth.Strategy.Pipedrive.OAuth.authorize_url!(opts))
  end

  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]

    case Ueberauth.Strategy.Pipedrive.OAuth.get_access_token([code: code], opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  def handle_cleanup!(conn) do
    conn
    |> put_private(:pipedrive_token, nil)
    |> put_private(:pipedrive_user, nil)
  end

  def uid(conn) do
    conn.private.pipedrive_user["id"]
  end

  def credentials(conn) do
    token = conn.private.pipedrive_token

    %Credentials{
      expires: true,
      expires_at: token.expires_at,
      token: token.access_token,
      refresh_token: token.refresh_token,
      token_type: token.token_type
    }
  end

  def info(conn) do
    user = conn.private.pipedrive_user

    %Info{
      email: user["email"],
      name: user["name"]
    }
  end

  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.pipedrive_token,
        user: conn.private.pipedrive_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :pipedrive_token, token)

    # Fetch user info from Pipedrive API
    client = Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://api.pipedrive.com/v1"},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{token.access_token}"}]}
    ])

    case Tesla.get(client, "/users/me") do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => user}}} ->
        put_private(conn, :pipedrive_user, user)

      {:error, reason} ->
        set_errors!(conn, [error("user_fetch_error", inspect(reason))])
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
```

---

## Part 6: Add Configuration

Update `config/config.exs` to register the Ueberauth provider:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [...]},
    hubspot: {Ueberauth.Strategy.Hubspot, [default_scope: "..."]},
    salesforce: {Ueberauth.Strategy.Salesforce, [default_scope: "..."]},
    pipedrive: {Ueberauth.Strategy.Pipedrive, [default_scope: "contacts:read contacts:write"]}
  ]
```

Update `config/runtime.exs` to read OAuth credentials:

```elixir
config :ueberauth, Ueberauth.Strategy.Pipedrive.OAuth,
  client_id: System.get_env("PIPEDRIVE_CLIENT_ID"),
  client_secret: System.get_env("PIPEDRIVE_CLIENT_SECRET")
```

Update `.envrc` or `.env.example`:

```bash
# Pipedrive (optional)
PIPEDRIVE_CLIENT_ID=your_pipedrive_client_id
PIPEDRIVE_CLIENT_SECRET=your_pipedrive_client_secret
```

---

## Part 7: Add the Auth Route

Update `lib/social_scribe_web/router.ex` to include the callback route:

```elixir
scope "/auth", SocialScribeWeb do
  pipe_through [:browser]

  get "/:provider", AuthController, :request
  get "/:provider/callback", AuthController, :callback
end
```

If this scope already exists, you just need to ensure your new provider is handled. The existing `AuthController` should work since it uses dynamic provider handling.

---

## Part 8: Add UI in Settings

Update the settings page to show a "Connect Pipedrive" button. In `lib/social_scribe_web/live/user_settings_live.html.heex`, add a new integration card in the CRM section:

```heex
<.integration_card
  provider="pipedrive"
  name="Pipedrive"
  description="Connect your Pipedrive account"
  credentials={@pipedrive_credentials}
  connect_path={~p"/auth/pipedrive"}
/>
```

Make sure the LiveView assigns `@pipedrive_credentials` by querying for credentials with provider "pipedrive".

---

## Part 9: Testing

Create test files for your adapter:

```
test/social_scribe/crm/adapters/pipedrive_test.exs
test/social_scribe/crm/adapters/pipedrive_fields_test.exs
```

Use Mox to mock HTTP calls. Here is a basic structure:

```elixir
defmodule SocialScribe.Crm.Adapters.PipedriveTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.Crm.Adapters.Pipedrive
  alias SocialScribe.Accounts.UserCredential

  import Tesla.Mock

  setup do
    mock_global(fn
      %{method: :get, url: "https://api.pipedrive.com/v1/persons/search" <> _} ->
        json(%{
          "data" => %{
            "items" => [
              %{"item" => %{"id" => 1, "first_name" => "John", "last_name" => "Doe"}}
            ]
          }
        })
    end)

    credential = %UserCredential{
      token: "test-token",
      refresh_token: "test-refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      provider: "pipedrive"
    }

    {:ok, credential: credential}
  end

  describe "search_contacts/2" do
    test "returns contacts matching query", %{credential: cred} do
      assert {:ok, contacts} = Pipedrive.search_contacts(cred, "John")
      assert length(contacts) == 1
    end
  end
end
```

---

## Checklist

Before considering your integration complete, verify:

- [ ] Field mapping module created with all relevant fields
- [ ] Adapter implements all six callbacks from `Crm.Behaviour`
- [ ] Adapter registered in `Crm.Registry` with provider string and label
- [ ] Ueberauth OAuth module created
- [ ] Ueberauth strategy module created
- [ ] Provider added to Ueberauth config in `config/config.exs`
- [ ] OAuth credentials configured in `config/runtime.exs`
- [ ] Environment variables documented in `.envrc` or `.env.example`
- [ ] UI added to settings page for connecting the CRM
- [ ] Tests written for adapter and field mappings
- [ ] Token refresh works correctly
- [ ] Search, get, and update operations all function properly

---

## File Reference

After adding Pipedrive, your file structure should include:

```
lib/social_scribe/crm/
  adapters/
    pipedrive.ex
    pipedrive_fields.ex
  registry.ex (updated)

lib/ueberauth/strategy/
  pipedrive.ex
  pipedrive/
    oauth.ex

config/
  config.exs (updated)
  runtime.exs (updated)
```
