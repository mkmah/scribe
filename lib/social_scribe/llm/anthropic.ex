defmodule SocialScribe.LLM.Anthropic do
  @moduledoc """
  Anthropic Claude provider for the LLM behaviour.

  ## Configuration

      # config/runtime.exs
      config :social_scribe, :anthropic_base_url, System.get_env("ANTHROPIC_BASE_URL")
      config :social_scribe, :anthropic_auth_token, System.get_env("ANTHROPIC_AUTH_TOKEN")
      config :social_scribe, :anthropic_model, System.get_env("ANTHROPIC_MODEL") || "claude-sonnet-4-20250514"
  """

  @behaviour SocialScribe.LLM.Provider

  @default_model "claude-sonnet-4-20250514"
  @default_base_url "https://api.anthropic.com"
  # @anthropic_version "2023-06-01"
  @max_tokens 4096

  @impl true
  def complete(prompt) do
    base_url = Application.get_env(:social_scribe, :anthropic_base_url) || @default_base_url
    auth_token = Application.get_env(:social_scribe, :anthropic_auth_token)
    model = Application.get_env(:social_scribe, :anthropic_model) || @default_model

    cond do
      is_nil(auth_token) or auth_token == "" ->
        {:error,
         {:config_error, "Anthropic auth token is missing – set ANTHROPIC_AUTH_TOKEN env var"}}

      true ->
        payload = %{
          model: model,
          max_tokens: @max_tokens,
          messages: [
            %{role: "user", content: prompt}
          ]
        }

        case Tesla.post(client(base_url, auth_token), "/v1/messages", payload) do
          {:ok, %Tesla.Env{status: 200, body: body}} ->
            extract_text(body)

          {:ok, %Tesla.Env{status: status, body: error_body}} ->
            {:error, {:api_error, status, error_body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
    end
  end

  defp extract_text(%{"content" => [%{"type" => "text", "text" => text} | _]}) do
    {:ok, text}
  end

  defp extract_text(%{"content" => content}) when is_list(content) do
    case Enum.find(content, &(&1["type"] == "text")) do
      %{"text" => text} -> {:ok, text}
      _ -> {:error, {:parsing_error, "No text block in Anthropic response", content}}
    end
  end

  defp extract_text(body) do
    {:error, {:parsing_error, "Unexpected Anthropic response structure", body}}
  end

  defp client(base_url, auth_token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"x-api-key", auth_token},
         #  {"anthropic-version", @anthropic_version},
         {"content-type", "application/json"}
       ]}
    ])
  end
end
