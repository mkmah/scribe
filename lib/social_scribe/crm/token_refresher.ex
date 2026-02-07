defmodule SocialScribe.Crm.TokenRefresher do
  @moduledoc """
  Generic token refresh logic for all CRM providers.

  Provides `ensure_valid_token/2` which checks expiry and delegates
  to the adapter's `refresh_token/1` callback, and `with_token_refresh/3`
  which wraps an API call with automatic retry on auth errors.
  """

  alias SocialScribe.Accounts.UserCredential

  @buffer_seconds 300

  @doc """
  Ensures a credential has a valid (non-expired) token.
  Refreshes if expired or about to expire (within 5 minutes).
  Delegates to the adapter's `refresh_token/1` callback.
  """
  @spec ensure_valid_token(UserCredential.t(), module()) ::
          {:ok, UserCredential.t()} | {:error, any()}
  def ensure_valid_token(%UserCredential{} = credential, adapter) do
    threshold = DateTime.add(DateTime.utc_now(), @buffer_seconds, :second)

    if DateTime.compare(credential.expires_at, threshold) == :lt do
      adapter.refresh_token(credential)
    else
      {:ok, credential}
    end
  end

  @doc """
  Wraps an API call with token refresh logic.
  Ensures valid token first, makes the call, and retries once on 401.
  """
  @spec with_token_refresh(UserCredential.t(), module(), (UserCredential.t() -> any())) :: any()
  def with_token_refresh(%UserCredential{} = credential, adapter, api_call) do
    with {:ok, credential} <- ensure_valid_token(credential, adapter) do
      case api_call.(credential) do
        {:error, {:api_error, status, body}} when status in [401, 400] ->
          if is_token_error?(body) do
            retry_with_fresh_token(credential, adapter, api_call)
          else
            {:error, {:api_error, status, body}}
          end

        other ->
          other
      end
    end
  end

  defp retry_with_fresh_token(credential, adapter, api_call) do
    case adapter.refresh_token(credential) do
      {:ok, refreshed_credential} ->
        api_call.(refreshed_credential)

      {:error, refresh_error} ->
        {:error, {:token_refresh_failed, refresh_error}}
    end
  end

  defp is_token_error?(%{"status" => status}) when status in ["BAD_CLIENT_ID", "UNAUTHORIZED"],
    do: true

  defp is_token_error?(%{"message" => msg}) when is_binary(msg) do
    String.contains?(String.downcase(msg), ["token", "expired", "unauthorized", "client id"])
  end

  defp is_token_error?(_), do: false
end
