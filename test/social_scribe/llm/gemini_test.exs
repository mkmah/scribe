defmodule SocialScribe.LLM.GeminiTest do
  use ExUnit.Case, async: false

  alias SocialScribe.LLM.Gemini

  @valid_body %{
    "candidates" => [
      %{
        "content" => %{
          "parts" => [%{"text" => "Hello from Gemini"}]
        }
      }
    ]
  }

  describe "complete/1" do
    test "returns config error when API key is missing" do
      Application.put_env(:social_scribe, :gemini_api_key, nil)
      assert {:error, {:config_error, msg}} = Gemini.complete("Hi")
      assert msg =~ "GEMINI_API_KEY"

      Application.put_env(:social_scribe, :gemini_api_key, "")
      assert {:error, {:config_error, _}} = Gemini.complete("Hi")
      Application.delete_env(:social_scribe, :gemini_api_key)
    end

    test "returns ok with text when API returns 200 with valid structure" do
      Application.put_env(:social_scribe, :gemini_api_key, "test-key")

      Tesla.Mock.mock(fn
        %{method: :post, url: url} ->
          assert url =~ "key=test-key"
          %Tesla.Env{status: 200, body: @valid_body}
      end)

      assert {:ok, "Hello from Gemini"} = Gemini.complete("Hello")

      Application.delete_env(:social_scribe, :gemini_api_key)
    end

    test "returns parsing error when response has no text content" do
      Application.put_env(:social_scribe, :gemini_api_key, "test-key")
      body = %{"candidates" => [%{"content" => %{"parts" => []}}]}

      Tesla.Mock.mock(fn %{method: :post} -> %Tesla.Env{status: 200, body: body} end)

      assert {:error, {:parsing_error, "No text content found in Gemini response", _}} =
               Gemini.complete("Prompt")

      Application.delete_env(:social_scribe, :gemini_api_key)
    end

    test "returns parsing error when candidates or content missing" do
      Application.put_env(:social_scribe, :gemini_api_key, "test-key")
      body = %{}

      Tesla.Mock.mock(fn %{method: :post} -> %Tesla.Env{status: 200, body: body} end)

      assert {:error, {:parsing_error, "No text content found in Gemini response", _}} =
               Gemini.complete("Prompt")

      Application.delete_env(:social_scribe, :gemini_api_key)
    end

    test "returns api_error when API returns non-200 status" do
      Application.put_env(:social_scribe, :gemini_api_key, "test-key")
      Tesla.Mock.mock(fn %{method: :post} ->
        %Tesla.Env{status: 403, body: %{"error" => "Forbidden"}}
      end)

      assert {:error, {:api_error, 403, _}} = Gemini.complete("Prompt")

      Application.delete_env(:social_scribe, :gemini_api_key)
    end

    test "returns http_error when request fails" do
      Application.put_env(:social_scribe, :gemini_api_key, "test-key")
      Tesla.Mock.mock(fn %{method: :post} -> {:error, :econnrefused} end)

      assert {:error, {:http_error, :econnrefused}} = Gemini.complete("Prompt")

      Application.delete_env(:social_scribe, :gemini_api_key)
    end

    test "uses custom model when configured" do
      Application.put_env(:social_scribe, :gemini_api_key, "test-key")
      Application.put_env(:social_scribe, :gemini_model, "gemini-1.5-pro")

      Tesla.Mock.mock(fn env ->
        assert env.url =~ "gemini-1.5-pro"
        %Tesla.Env{status: 200, body: @valid_body}
      end)

      assert {:ok, "Hello from Gemini"} = Gemini.complete("Hi")

      Application.delete_env(:social_scribe, :gemini_model)
      Application.delete_env(:social_scribe, :gemini_api_key)
    end
  end
end
