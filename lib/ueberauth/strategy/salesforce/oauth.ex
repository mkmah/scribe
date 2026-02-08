defmodule Ueberauth.Strategy.Salesforce.OAuth do
  @moduledoc """
  OAuth2 for Salesforce.

  Add `client_id` and `client_secret` to your configuration:

      config :ueberauth, Ueberauth.Strategy.Salesforce.OAuth,
        client_id: System.get_env("SALESFORCE_CLIENT_ID"),
        client_secret: System.get_env("SALESFORCE_CLIENT_SECRET")
  """

  use OAuth2.Strategy

  require Logger

  @defaults [
    strategy: __MODULE__,
    site: "https://login.salesforce.com",
    authorize_url: "/services/oauth2/authorize",
    token_url: "/services/oauth2/token"
  ]

  @doc """
  Construct a client for requests to Salesforce.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])
    opts = @defaults |> Keyword.merge(opts) |> Keyword.merge(config) |> resolve_values()
    json_library = Ueberauth.json_library()

    OAuth2.Client.new(opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  @doc """
  Fetches a resource using the OAuth2 token.
  Used for fetching user info after token exchange.
  """
  def get(token, url, headers \\ [], opts \\ []) do
    [token: token]
    |> client()
    |> put_param("client_secret", client().client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  @doc """
  Fetches an access token from the Salesforce token endpoint.

  When `code_verifier` is present in params, uses a direct HTTP POST
  for the PKCE flow (bypasses OAuth2 library to avoid sending client_secret).
  Otherwise uses the standard OAuth2 library flow.
  """
  def get_access_token(params \\ [], opts \\ []) do
    {code_verifier, params} = Keyword.pop(params, :code_verifier)

    if code_verifier do
      get_access_token_pkce(params, code_verifier, opts)
    else
      get_access_token_standard(params, opts)
    end
  end

  # PKCE token exchange: direct HTTP POST with full control over params.
  # Includes client_secret for confidential clients that require both PKCE + secret.
  defp get_access_token_pkce(params, code_verifier, opts) do
    c = client(opts)

    body_params = %{
      "grant_type" => "authorization_code",
      "code" => params[:code],
      "client_id" => c.client_id,
      "client_secret" => c.client_secret,
      "code_verifier" => code_verifier,
      "redirect_uri" => c.redirect_uri
    }

    # Remove client_secret if it's empty (public client)
    body_params =
      if c.client_secret in [nil, ""] do
        Map.delete(body_params, "client_secret")
      else
        body_params
      end

    body = URI.encode_query(body_params)

    token_url = "#{c.site}/services/oauth2/token"
    Logger.info("Salesforce PKCE token exchange: POST #{token_url}")

    Logger.debug(
      "Salesforce PKCE params: client_id=#{String.slice(c.client_id || "", 0..10)}..., client_secret_present=#{c.client_secret not in [nil, ""]}, redirect_uri=#{c.redirect_uri}"
    )

    headers = [
      {"content-type", "application/x-www-form-urlencoded"},
      {"accept", "application/json"}
    ]

    case Tesla.post(http_client(), token_url, body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: resp_body}} ->
        Logger.info("Salesforce PKCE token exchange succeeded")
        token = build_access_token(resp_body)
        {:ok, token}

      {:ok, %Tesla.Env{body: %{"error" => error, "error_description" => description}}} ->
        Logger.error("Salesforce PKCE token error: #{error} - #{description}")
        {:error, {error, description}}

      {:ok, %Tesla.Env{status: status, body: resp_body}} ->
        Logger.error("Salesforce PKCE token unexpected #{status}: #{inspect(resp_body)}")
        {:error, {"token_error", "Unexpected response (#{status}) from Salesforce"}}

      {:error, reason} ->
        Logger.error("Salesforce PKCE token HTTP error: #{inspect(reason)}")
        {:error, {"http_error", inspect(reason)}}
    end
  end

  # Standard token exchange via OAuth2 library (with client_secret)
  defp get_access_token_standard(params, opts) do
    Logger.info("Salesforce standard token exchange")

    case opts |> client() |> OAuth2.Client.get_token(params) do
      {:error, %{body: %{"error" => error, "error_description" => description}}} ->
        Logger.error("Salesforce token error: #{error} - #{description}")
        {:error, {error, description}}

      {:ok, %{token: %{access_token: nil} = token}} ->
        %{"error" => error, "error_description" => description} = token.other_params
        Logger.error("Salesforce token error (nil access_token): #{error} - #{description}")
        {:error, {error, description}}

      {:ok, %{token: token}} ->
        Logger.info("Salesforce standard token exchange succeeded")
        {:ok, token}

      other ->
        Logger.error("Salesforce token unexpected response: #{inspect(other)}")
        {:error, {"unexpected_error", "Unexpected response from Salesforce"}}
    end
  end

  # Build an OAuth2.AccessToken struct from the raw Salesforce JSON response
  defp build_access_token(resp) do
    %OAuth2.AccessToken{
      access_token: resp["access_token"],
      refresh_token: resp["refresh_token"],
      token_type: resp["token_type"] || "Bearer",
      expires_at: parse_expires_at(resp),
      other_params:
        Map.drop(resp, ["access_token", "refresh_token", "token_type", "expires_in", "issued_at"])
    }
  end

  defp parse_expires_at(%{"issued_at" => issued_at_ms}) do
    # Salesforce returns issued_at as milliseconds since epoch string
    case Integer.parse(issued_at_ms) do
      {ms, _} ->
        # Salesforce tokens typically expire in 2 hours
        div(ms, 1000) + 7200

      :error ->
        nil
    end
  end

  defp parse_expires_at(%{"expires_in" => expires_in}) when is_integer(expires_in) do
    System.system_time(:second) + expires_in
  end

  defp parse_expires_at(_), do: nil

  defp http_client do
    Tesla.client([Tesla.Middleware.JSON])
  end

  defp resolve_values(list) do
    for {key, value} <- list do
      {key, resolve_value(value)}
    end
  end

  defp resolve_value({m, f, a}) when is_atom(m) and is_atom(f), do: apply(m, f, a)
  defp resolve_value(v), do: v

  # OAuth2.Strategy callbacks

  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
