defmodule Ueberauth.Strategy.Salesforce do
  @moduledoc """
  Salesforce Strategy for Ueberauth.

  Supports PKCE (Proof Key for Code Exchange) which Salesforce requires
  for connected apps that have "Require Proof Key for Code Exchange" enabled.
  """

  use Ueberauth.Strategy,
    uid_field: :organization_id,
    default_scope: "openid refresh_token",
    userinfo_endpoint: "https://login.salesforce.com/services/oauth2/userinfo"

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  require Logger

  @doc """
  Handles initial request for Salesforce authentication.
  Generates PKCE code_verifier/code_challenge and stores verifier in session.
  """
  def handle_request!(conn) do
    # Generate PKCE parameters
    code_verifier = generate_code_verifier()
    code_challenge = generate_code_challenge(code_verifier)

    params =
      []
      |> with_optional(:scope, conn)
      |> with_optional(:prompt, conn)
      |> with_optional(:display, conn)
      |> with_optional(:login_hint, conn)
      |> with_param(:scope, conn)
      |> with_param(:prompt, conn)
      |> with_param(:display, conn)
      |> with_param(:login_hint, conn)
      |> Keyword.put(:code_challenge, code_challenge)
      |> Keyword.put(:code_challenge_method, "S256")
      |> with_state_param(conn)

    opts = oauth_client_options_from_conn(conn)

    conn
    |> put_session(:salesforce_code_verifier, code_verifier)
    |> redirect!(Ueberauth.Strategy.Salesforce.OAuth.authorize_url!(params, opts))
  end

  @doc """
  Handles the callback from Salesforce.
  Includes PKCE code_verifier in the token exchange.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    code_verifier = get_session(conn, :salesforce_code_verifier)
    Logger.info("Salesforce callback - code received, code_verifier present: #{!is_nil(code_verifier)}")

    params = [code: code, code_verifier: code_verifier]
    opts = oauth_client_options_from_conn(conn)

    case Ueberauth.Strategy.Salesforce.OAuth.get_access_token(params, opts) do
      {:ok, token} ->
        conn
        |> delete_session(:salesforce_code_verifier)
        |> fetch_user(token)

      {:error, {error_code, error_description}} ->
        Logger.error("Salesforce callback error: #{error_code} - #{error_description}")
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  def handle_callback!(%Plug.Conn{params: %{"error" => error}} = conn) do
    set_errors!(conn, [error(error, "Redirect error")])
  end

  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:salesforce_token, nil)
    |> put_private(:salesforce_user, nil)
  end

  @doc """
  Fetches the uid field from the response.
  Uses organization_id, falls back to user_id, then parses from sub URL.
  """
  def uid(conn) do
    user = conn.private.salesforce_user

    user["organization_id"] ||
      user["user_id"] ||
      parse_uid_from_sub(user["sub"])
  end

  defp parse_uid_from_sub(nil), do: nil

  defp parse_uid_from_sub(sub_url) do
    # sub is like "https://login.salesforce.com/id/00DgL00000KIt7NUAT/005gL00000EpoKTQAZ"
    # Extract the org_id (first ID segment after /id/)
    case String.split(sub_url, "/id/") do
      [_, ids] -> ids |> String.split("/") |> List.first()
      _ -> sub_url
    end
  end

  @doc """
  Includes the credentials from the Salesforce response.
  """
  def credentials(conn) do
    token = conn.private.salesforce_token
    scope_string = token.other_params["scope"] || ""
    scopes = String.split(scope_string, " ")

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      scopes: scopes,
      token_type: Map.get(token, :token_type),
      refresh_token: token.refresh_token,
      token: token.access_token,
      other: %{instance_url: token.other_params["instance_url"]}
    }
  end

  @doc """
  Fetches the fields to populate the info section.
  """
  def info(conn) do
    user = conn.private.salesforce_user

    %Info{
      email: user["email"],
      name: user["name"],
      first_name: user["given_name"] || user["givenName"],
      last_name: user["family_name"] || user["familyName"],
      image: user["picture"]
    }
  end

  @doc """
  Stores the raw information from the Salesforce callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.salesforce_token,
        user: conn.private.salesforce_user
      }
    }
  end

  # --- PKCE helpers ---

  defp generate_code_verifier do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp generate_code_challenge(code_verifier) do
    :crypto.hash(:sha256, code_verifier)
    |> Base.url_encode64(padding: false)
  end

  # --- Private helpers ---

  defp fetch_user(conn, token) do
    conn = put_private(conn, :salesforce_token, token)

    userinfo_url = get_userinfo_endpoint(conn, token)
    Logger.info("Salesforce fetching user info from: #{userinfo_url}")

    case Ueberauth.Strategy.Salesforce.OAuth.get(token, userinfo_url) do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        Logger.info("Salesforce user info fetched successfully")
        put_private(conn, :salesforce_user, user)

      {:error, %OAuth2.Response{status_code: status_code}} ->
        Logger.error("Salesforce user info error: #{status_code}")
        set_errors!(conn, [error("OAuth2", "#{status_code}")])

      {:error, %OAuth2.Error{reason: reason}} ->
        Logger.error("Salesforce user info error: #{inspect(reason)}")
        set_errors!(conn, [error("OAuth2", "#{inspect(reason)}")])
    end
  end

  defp get_userinfo_endpoint(conn, token) do
    # Prefer the instance_url from the token response (org-specific endpoint)
    instance_url = token.other_params["instance_url"]

    if instance_url do
      "#{instance_url}/services/oauth2/userinfo"
    else
      case option(conn, :userinfo_endpoint) do
        {:system, varname, default} ->
          System.get_env(varname) || default

        {:system, varname} ->
          System.get_env(varname) || Keyword.get(default_options(), :userinfo_endpoint)

        other ->
          other
      end
    end
  end

  defp oauth_client_options_from_conn(conn) do
    base_options = [redirect_uri: callback_url(conn)]
    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:client_secret]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
