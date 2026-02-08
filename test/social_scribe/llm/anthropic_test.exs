defmodule SocialScribe.LLM.AnthropicTest do
  use ExUnit.Case, async: false

  alias SocialScribe.LLM.Anthropic

  @valid_body %{"content" => [%{"type" => "text", "text" => "Hello from Claude"}]}

  describe "complete/1" do
    test "returns config error when auth token is missing" do
      Application.put_env(:social_scribe, :anthropic_auth_token, nil)
      assert {:error, {:config_error, msg}} = Anthropic.complete("Hi")
      assert msg =~ "ANTHROPIC_AUTH_TOKEN"

      Application.put_env(:social_scribe, :anthropic_auth_token, "")
      assert {:error, {:config_error, _}} = Anthropic.complete("Hi")
      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end

    test "returns ok with text when API returns 200 and content has text block" do
      Application.put_env(:social_scribe, :anthropic_auth_token, "test-token")

      Tesla.Mock.mock(fn
        %{method: :post, url: _} ->
          %Tesla.Env{status: 200, body: @valid_body}
      end)

      assert {:ok, "Hello from Claude"} = Anthropic.complete("Hello")

      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end

    test "extracts text when text block is not first in content list" do
      Application.put_env(:social_scribe, :anthropic_auth_token, "test-token")

      body = %{
        "content" => [
          %{"type" => "thinking", "thinking" => "..."},
          %{"type" => "text", "text" => "Final answer"}
        ]
      }

      Tesla.Mock.mock(fn %{method: :post} -> %Tesla.Env{status: 200, body: body} end)

      assert {:ok, "Final answer"} = Anthropic.complete("Prompt")

      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end

    test "returns parsing error when content has no text block" do
      Application.put_env(:social_scribe, :anthropic_auth_token, "test-token")
      body = %{"content" => [%{"type" => "image", "source" => %{}}]}

      Tesla.Mock.mock(fn %{method: :post} -> %Tesla.Env{status: 200, body: body} end)

      assert {:error, {:parsing_error, "No text block in Anthropic response", _}} =
               Anthropic.complete("Prompt")

      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end

    test "returns parsing error for unexpected response structure" do
      Application.put_env(:social_scribe, :anthropic_auth_token, "test-token")
      body = %{"error" => "something"}

      Tesla.Mock.mock(fn %{method: :post} -> %Tesla.Env{status: 200, body: body} end)

      assert {:error, {:parsing_error, "Unexpected Anthropic response structure", _}} =
               Anthropic.complete("Prompt")

      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end

    test "returns api_error when API returns non-200 status" do
      Application.put_env(:social_scribe, :anthropic_auth_token, "test-token")

      Tesla.Mock.mock(fn %{method: :post} ->
        %Tesla.Env{status: 401, body: %{"error" => "Unauthorized"}}
      end)

      assert {:error, {:api_error, 401, _}} = Anthropic.complete("Prompt")

      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end

    test "returns http_error when request fails" do
      Application.put_env(:social_scribe, :anthropic_auth_token, "test-token")
      Tesla.Mock.mock(fn %{method: :post} -> {:error, :timeout} end)

      assert {:error, {:http_error, :timeout}} = Anthropic.complete("Prompt")

      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end

    test "uses custom base_url and model when configured" do
      Application.put_env(:social_scribe, :anthropic_auth_token, "test-token")
      Application.put_env(:social_scribe, :anthropic_base_url, "https://custom.anthropic.com")
      Application.put_env(:social_scribe, :anthropic_model, "claude-3-opus")

      Tesla.Mock.mock(fn env ->
        assert String.starts_with?(env.url, "https://custom.anthropic.com")
        %Tesla.Env{status: 200, body: @valid_body}
      end)

      assert {:ok, "Hello from Claude"} = Anthropic.complete("Hi")

      Application.delete_env(:social_scribe, :anthropic_base_url)
      Application.delete_env(:social_scribe, :anthropic_model)
      Application.delete_env(:social_scribe, :anthropic_auth_token)
    end
  end
end
