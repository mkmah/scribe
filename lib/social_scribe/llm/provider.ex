defmodule SocialScribe.LLM.Provider do
  @moduledoc """
  Behaviour for LLM providers.

  Any LLM backend (Gemini, Anthropic, OpenAI, etc.) implements this
  single callback. The rest of the application only calls `complete/1`
  through the configured provider — never a vendor-specific function.

  ## Configuration

      # config/config.exs or config/runtime.exs
      config :social_scribe, :llm_provider, SocialScribe.LLM.Anthropic

  If no provider is configured, defaults to `SocialScribe.LLM.Anthropic`.
  """

  @doc """
  Sends a prompt to the LLM and returns the text response.
  """
  @callback complete(prompt :: String.t()) :: {:ok, String.t()} | {:error, any()}

  @doc """
  Calls `complete/1` on whichever provider is configured.
  """
  @spec complete(String.t()) :: {:ok, String.t()} | {:error, any()}
  def complete(prompt) do
    impl().complete(prompt)
  end

  defp impl do
    Application.get_env(:social_scribe, :llm_provider, SocialScribe.LLM.Anthropic)
  end
end
