defmodule SocialScribe.LLM.ProviderTest do
  use ExUnit.Case, async: false

  alias SocialScribe.LLM.Provider

  defmodule TestProvider do
    @behaviour SocialScribe.LLM.Provider

    @impl true
    def complete(prompt) do
      {:ok, "Response to: #{prompt}"}
    end
  end

  describe "complete/1" do
    test "delegates to configured provider and returns result" do
      Application.put_env(:social_scribe, :llm_provider, TestProvider)

      assert {:ok, "Response to: hello"} = Provider.complete("hello")

      Application.delete_env(:social_scribe, :llm_provider)
    end
  end
end
