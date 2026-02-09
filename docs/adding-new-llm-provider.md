# Adding a New LLM Provider

This guide walks you through how to add a new Large Language Model (LLM) provider to Social Scribe. The application uses a provider abstraction that makes it straightforward to swap between different LLM backends like Anthropic Claude, Google Gemini, or OpenAI.

## Overview

The default LLM provider is Anthropic Claude; Google Gemini is a supported alternative (set `LLM_PROVIDER=gemini`). This guide explains how to add further providers (e.g. OpenAI). The LLM system is built around a single behaviour defined in `lib/social_scribe/llm/provider.ex`. Any new provider you add must implement one callback function: `complete/1`. The rest of the application calls this function through the configured provider and never touches vendor-specific code directly.

## Step 1: Create the Provider Module

Create a new file in `lib/social_scribe/llm/` for your provider. For example, if you are adding OpenAI support, create `lib/social_scribe/llm/openai.ex`.

Here is a template you can use as a starting point:

```elixir
defmodule SocialScribe.LLM.OpenAI do
  @moduledoc """
  OpenAI provider for the LLM behaviour.

  ## Configuration

      # config/runtime.exs
      config :social_scribe, :openai_api_key, System.get_env("OPENAI_API_KEY")
      config :social_scribe, :openai_model, System.get_env("OPENAI_MODEL") || "gpt-4"
  """

  @behaviour SocialScribe.LLM.Provider

  @default_model "gpt-4"
  @base_url "https://api.openai.com"

  @impl true
  def complete(prompt) do
    api_key = Application.get_env(:social_scribe, :openai_api_key)
    model = Application.get_env(:social_scribe, :openai_model) || @default_model

    if is_nil(api_key) or api_key == "" do
      {:error, {:config_error, "OpenAI API key is missing – set OPENAI_API_KEY env var"}}
    else
      payload = %{
        model: model,
        messages: [
          %{role: "user", content: prompt}
        ]
      }

      case Tesla.post(client(api_key), "/v1/chat/completions", payload) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          extract_text(body)

        {:ok, %Tesla.Env{status: status, body: error_body}} ->
          {:error, {:api_error, status, error_body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end
  end

  defp extract_text(%{"choices" => [%{"message" => %{"content" => text}} | _]}) do
    {:ok, text}
  end

  defp extract_text(body) do
    {:error, {:parsing_error, "Unexpected OpenAI response structure", body}}
  end

  defp client(api_key) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{api_key}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end
end
```

## Step 2: Understand the Required Callback

Your provider module must implement the `complete/1` callback defined in the behaviour:

```elixir
@callback complete(prompt :: String.t()) :: {:ok, String.t()} | {:error, any()}
```

This function receives a prompt string and must return either:

- `{:ok, text}` where `text` is the generated response from the LLM
- `{:error, reason}` where `reason` describes what went wrong

The error tuples in the codebase typically follow these patterns:

- `{:error, {:config_error, message}}` for missing configuration
- `{:error, {:api_error, status_code, body}}` for HTTP errors from the API
- `{:error, {:http_error, reason}}` for network-level failures
- `{:error, {:parsing_error, message, body}}` for unexpected response structures

## Step 3: Add Configuration

Add your provider's configuration to `config/runtime.exs`. This is where environment variables are read and mapped to application configuration:

```elixir
# OpenAI Configuration
config :social_scribe, :openai_api_key, System.get_env("OPENAI_API_KEY")
config :social_scribe, :openai_model, System.get_env("OPENAI_MODEL") || "gpt-4"
```

Document the new environment variables in the [README](../README.md) (Getting Started) or [Deployment Guide](deployment.md), and in your local `.envrc` if you use one:

```bash
# OpenAI (optional, alternative to Anthropic/Gemini)
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-4
```

## Step 4: Configure the Application to Use Your Provider

To switch the application to use your new provider, update the `:llm_provider` configuration in `config/runtime.exs`:

```elixir
config :social_scribe, :llm_provider, SocialScribe.LLM.OpenAI
```

Alternatively, you can make this configurable via an environment variable:

```elixir
llm_provider =
  case System.get_env("LLM_PROVIDER") do
    "openai" -> SocialScribe.LLM.OpenAI
    "gemini" -> SocialScribe.LLM.Gemini
    _ -> SocialScribe.LLM.Anthropic
  end

config :social_scribe, :llm_provider, llm_provider
```

## Step 5: Test Your Provider

Create a test file at `test/social_scribe/llm/openai_test.exs`. Since LLM calls involve external APIs, you will typically want to mock the HTTP layer:

```elixir
defmodule SocialScribe.LLM.OpenAITest do
  use ExUnit.Case, async: true

  alias SocialScribe.LLM.OpenAI

  import Tesla.Mock

  setup do
    mock(fn
      %{method: :post, url: "https://api.openai.com/v1/chat/completions"} ->
        json(%{
          "choices" => [
            %{"message" => %{"content" => "Hello from OpenAI!"}}
          ]
        })
    end)

    # Set required config for tests
    Application.put_env(:social_scribe, :openai_api_key, "test-key")
    :ok
  end

  describe "complete/1" do
    test "returns generated text on success" do
      assert {:ok, "Hello from OpenAI!"} = OpenAI.complete("Say hello")
    end

    test "returns error when API key is missing" do
      Application.put_env(:social_scribe, :openai_api_key, nil)
      assert {:error, {:config_error, _}} = OpenAI.complete("Say hello")
    end
  end
end
```

## How the Provider System Works

When the application needs to generate AI content, it goes through `SocialScribe.AIContentGenerator`, which constructs prompts and calls `SocialScribe.LLM.Provider.complete/1`. The `Provider` module looks up which implementation to use from the application configuration:

```elixir
defp impl do
  Application.get_env(:social_scribe, :llm_provider, SocialScribe.LLM.Anthropic)
end
```

This means you never need to change the calling code. All AI content generation, whether it is follow-up emails, automation content, or CRM suggestions, will automatically use whichever provider you configure.

## File Structure

After adding your provider, the LLM directory should look like this:

```text
lib/social_scribe/llm/
  provider.ex         # Behaviour definition
  anthropic.ex        # Anthropic Claude implementation
  gemini.ex           # Google Gemini implementation
  openai.ex           # Your new OpenAI implementation
```

## Troubleshooting

If your provider is not being used:

1. Check that `config :social_scribe, :llm_provider` is set to your module
2. Verify the configuration is being loaded (check `Application.get_env(:social_scribe, :llm_provider)` in IEx)
3. Make sure your module properly declares `@behaviour SocialScribe.LLM.Provider` and uses `@impl true`

If you are getting unexpected errors:

1. Test your HTTP client setup independently using Tesla
2. Check the API response structure matches what your `extract_text/1` function expects
3. Look at the existing Anthropic and Gemini implementations for reference patterns
