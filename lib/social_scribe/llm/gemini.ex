defmodule SocialScribe.LLM.Gemini do
  @moduledoc """
  Google Gemini provider for the LLM behaviour.

  ## Configuration

      # config/runtime.exs
      config :social_scribe, :gemini_api_key, System.get_env("GEMINI_API_KEY")
      config :social_scribe, :gemini_model, System.get_env("GEMINI_MODEL") || "gemini-2.0-flash-lite"
  """

  @behaviour SocialScribe.LLM.Provider

  @default_model "gemini-2.0-flash-lite"
  @base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @impl true
  def complete(prompt) do
    api_key = Application.get_env(:social_scribe, :gemini_api_key)
    model = Application.get_env(:social_scribe, :gemini_model) || @default_model

    if is_nil(api_key) or api_key == "" do
      {:error, {:config_error, "Gemini API key is missing – set GEMINI_API_KEY env var"}}
    else
      path = "/#{model}:generateContent?key=#{api_key}"

      payload = %{
        contents: [
          %{
            parts: [%{text: prompt}]
          }
        ]
      }

      case Tesla.post(client(), path, payload) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          extract_text(body)

        {:ok, %Tesla.Env{status: status, body: error_body}} ->
          {:error, {:api_error, status, error_body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end
  end

  defp extract_text(body) do
    text_path = [
      "candidates",
      Access.at(0),
      "content",
      "parts",
      Access.at(0),
      "text"
    ]

    case get_in(body, text_path) do
      nil -> {:error, {:parsing_error, "No text content found in Gemini response", body}}
      text_content -> {:ok, text_content}
    end
  end

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      Tesla.Middleware.JSON
    ])
  end
end
