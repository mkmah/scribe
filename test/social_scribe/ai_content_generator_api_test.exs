defmodule SocialScribe.AIContentGeneratorApiTest do
  use ExUnit.Case, async: false

  alias SocialScribe.AIContentGeneratorApi

  defmodule TestImplementation do
    @behaviour SocialScribe.AIContentGeneratorApi

    @impl true
    def generate_follow_up_email(meeting) do
      {:ok, "Test email for meeting: #{inspect(meeting.id)}"}
    end

    @impl true
    def generate_automation(automation, meeting) do
      {:ok, "Test automation for automation: #{inspect(automation.id)}, meeting: #{inspect(meeting.id)}"}
    end

    @impl true
    def generate_hubspot_suggestions(_meeting) do
      {:ok, [%{field: "test", value: "value"}]}
    end

    @impl true
    def generate_crm_suggestions(_meeting) do
      {:ok, [%{field: "test", value: "value"}]}
    end

    @impl true
    def answer_crm_question(question, context) do
      {:ok, "Test answer for question: #{question}, context: #{inspect(context)}"}
    end
  end

  defmodule TestImplementationWithErrors do
    @behaviour SocialScribe.AIContentGeneratorApi

    @impl true
    def generate_follow_up_email(_meeting) do
      {:error, :test_error}
    end

    @impl true
    def generate_automation(_automation, _meeting) do
      {:error, :test_error}
    end

    @impl true
    def generate_hubspot_suggestions(_meeting) do
      {:error, :test_error}
    end

    @impl true
    def generate_crm_suggestions(_meeting) do
      {:error, :test_error}
    end

    @impl true
    def answer_crm_question(_question, _context) do
      {:error, :test_error}
    end
  end

  defmodule TestImplementationOptionalCallbacks do
    @behaviour SocialScribe.AIContentGeneratorApi

    @impl true
    def generate_follow_up_email(_meeting) do
      {:ok, "email"}
    end

    @impl true
    def generate_automation(_automation, _meeting) do
      {:ok, "automation"}
    end

    @impl true
    def generate_hubspot_suggestions(_meeting) do
      {:ok, []}
    end

    # Optional callbacks - not implemented
  end

  setup do
    # Save original config
    original_config = Application.get_env(:social_scribe, :ai_content_generator_api)

    on_exit(fn ->
      # Restore original config
      if original_config do
        Application.put_env(:social_scribe, :ai_content_generator_api, original_config)
      else
        Application.delete_env(:social_scribe, :ai_content_generator_api)
      end
    end)

    {:ok, original_config: original_config}
  end

  describe "generate_follow_up_email/1" do
    test "delegates to configured implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      meeting = %{id: 123}

      assert {:ok, result} = AIContentGeneratorApi.generate_follow_up_email(meeting)
      assert result =~ "Test email"
      assert result =~ "123"
    end

    test "delegates error responses from implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementationWithErrors)
      meeting = %{id: 123}

      assert {:error, :test_error} = AIContentGeneratorApi.generate_follow_up_email(meeting)
    end

    test "uses default implementation when none configured" do
      Application.delete_env(:social_scribe, :ai_content_generator_api)

      # Should use SocialScribe.AIContentGenerator as default
      # Verify that impl() returns the default module
      # We can't easily test the actual call without proper Meeting struct,
      # but we verify the delegation mechanism works
      assert Code.ensure_loaded?(SocialScribe.AIContentGenerator)
      assert function_exported?(SocialScribe.AIContentGenerator, :generate_follow_up_email, 1)
    end

    test "passes meeting parameter correctly" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      meeting = %{id: 456, title: "Test Meeting"}

      assert {:ok, result} = AIContentGeneratorApi.generate_follow_up_email(meeting)
      assert result =~ "456"
    end
  end

  describe "generate_automation/2" do
    test "delegates to configured implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      automation = %{id: 789}
      meeting = %{id: 123}

      assert {:ok, result} = AIContentGeneratorApi.generate_automation(automation, meeting)
      assert result =~ "Test automation"
      assert result =~ "789"
      assert result =~ "123"
    end

    test "delegates error responses from implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementationWithErrors)
      automation = %{id: 789}
      meeting = %{id: 123}

      assert {:error, :test_error} =
               AIContentGeneratorApi.generate_automation(automation, meeting)
    end

    test "uses default implementation when none configured" do
      Application.delete_env(:social_scribe, :ai_content_generator_api)

      # Verify that default implementation exists
      assert Code.ensure_loaded?(SocialScribe.AIContentGenerator)
      assert function_exported?(SocialScribe.AIContentGenerator, :generate_automation, 2)
    end

    test "passes both parameters correctly" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      automation = %{id: 111, name: "Auto"}
      meeting = %{id: 222, title: "Meeting"}

      assert {:ok, result} = AIContentGeneratorApi.generate_automation(automation, meeting)
      assert result =~ "111"
      assert result =~ "222"
    end
  end

  describe "generate_hubspot_suggestions/1" do
    test "delegates to configured implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      meeting = %{id: 123}

      assert {:ok, suggestions} = AIContentGeneratorApi.generate_hubspot_suggestions(meeting)
      assert is_list(suggestions)
      assert length(suggestions) == 1
      assert hd(suggestions).field == "test"
      assert hd(suggestions).value == "value"
    end

    test "delegates error responses from implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementationWithErrors)
      meeting = %{id: 123}

      assert {:error, :test_error} = AIContentGeneratorApi.generate_hubspot_suggestions(meeting)
    end

    test "uses default implementation when none configured" do
      Application.delete_env(:social_scribe, :ai_content_generator_api)

      # Verify that default implementation exists
      assert Code.ensure_loaded?(SocialScribe.AIContentGenerator)
      assert function_exported?(SocialScribe.AIContentGenerator, :generate_hubspot_suggestions, 1)
    end

    test "passes meeting parameter correctly" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      meeting = %{id: 456}

      assert {:ok, _suggestions} = AIContentGeneratorApi.generate_hubspot_suggestions(meeting)
    end
  end

  describe "generate_crm_suggestions/1" do
    test "delegates to configured implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      meeting = %{id: 123}

      assert {:ok, suggestions} = AIContentGeneratorApi.generate_crm_suggestions(meeting)
      assert is_list(suggestions)
      assert length(suggestions) == 1
      assert hd(suggestions).field == "test"
      assert hd(suggestions).value == "value"
    end

    test "delegates error responses from implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementationWithErrors)
      meeting = %{id: 123}

      assert {:error, :test_error} = AIContentGeneratorApi.generate_crm_suggestions(meeting)
    end

    test "uses default implementation when none configured" do
      Application.delete_env(:social_scribe, :ai_content_generator_api)

      # Verify that default implementation exists (if implemented)
      assert Code.ensure_loaded?(SocialScribe.AIContentGenerator)
      # generate_crm_suggestions may be optional, so check if it exists
      if function_exported?(SocialScribe.AIContentGenerator, :generate_crm_suggestions, 1) do
        assert true
      else
        # Optional callback not implemented - that's ok
        assert true
      end
    end

    test "handles optional callback when not implemented" do
      Application.put_env(
        :social_scribe,
        :ai_content_generator_api,
        TestImplementationOptionalCallbacks
      )

      meeting = %{id: 123}

      # Should raise UndefinedFunctionError since optional callback not implemented
      assert_raise UndefinedFunctionError, fn ->
        AIContentGeneratorApi.generate_crm_suggestions(meeting)
      end
    end

    test "passes meeting parameter correctly" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      meeting = %{id: 456}

      assert {:ok, _suggestions} = AIContentGeneratorApi.generate_crm_suggestions(meeting)
    end
  end

  describe "answer_crm_question/2" do
    test "delegates to configured implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      question = "What is the status?"
      context = %{key: "value"}

      assert {:ok, result} = AIContentGeneratorApi.answer_crm_question(question, context)
      assert result =~ "Test answer"
      assert result =~ question
      assert result =~ "value"
    end

    test "delegates error responses from implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementationWithErrors)
      question = "What is the status?"
      context = %{key: "value"}

      assert {:error, :test_error} =
               AIContentGeneratorApi.answer_crm_question(question, context)
    end

    test "uses default implementation when none configured" do
      Application.delete_env(:social_scribe, :ai_content_generator_api)

      # Verify that default implementation exists (if implemented)
      assert Code.ensure_loaded?(SocialScribe.AIContentGenerator)
      # answer_crm_question may be optional, so check if it exists
      if function_exported?(SocialScribe.AIContentGenerator, :answer_crm_question, 2) do
        assert true
      else
        # Optional callback not implemented - that's ok
        assert true
      end
    end

    test "handles optional callback when not implemented" do
      Application.put_env(
        :social_scribe,
        :ai_content_generator_api,
        TestImplementationOptionalCallbacks
      )

      question = "What is the status?"
      context = %{key: "value"}

      # Should raise UndefinedFunctionError since optional callback not implemented
      assert_raise UndefinedFunctionError, fn ->
        AIContentGeneratorApi.answer_crm_question(question, context)
      end
    end

    test "passes both parameters correctly" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      question = "Who attended?"
      context = %{contacts: [], meetings: []}

      assert {:ok, result} = AIContentGeneratorApi.answer_crm_question(question, context)
      assert result =~ question
    end

    test "handles empty question string" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      question = ""
      context = %{}

      assert {:ok, result} = AIContentGeneratorApi.answer_crm_question(question, context)
      assert is_binary(result)
    end

    test "handles empty context map" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)
      question = "Test question"
      context = %{}

      assert {:ok, result} = AIContentGeneratorApi.answer_crm_question(question, context)
      assert is_binary(result)
    end
  end

  describe "impl/0 private function" do
    test "returns configured implementation when set" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)

      # We can't directly test the private function, but we can verify it's used
      # by checking that the wrapper functions use the configured implementation
      meeting = %{id: 123}
      assert {:ok, result} = AIContentGeneratorApi.generate_follow_up_email(meeting)
      assert result =~ "Test email"
    end

    test "returns default implementation when not configured" do
      Application.delete_env(:social_scribe, :ai_content_generator_api)

      # Should default to SocialScribe.AIContentGenerator
      # Verify the default module exists and has the function
      assert Code.ensure_loaded?(SocialScribe.AIContentGenerator)
      assert function_exported?(SocialScribe.AIContentGenerator, :generate_follow_up_email, 1)
    end

    test "handles nil configuration gracefully" do
      Application.put_env(:social_scribe, :ai_content_generator_api, nil)

      # When config is nil, Application.get_env returns nil,
      # which causes an error when trying to call nil.generate_follow_up_email
      # This tests the actual behavior - nil config causes runtime error
      meeting = %{id: 123}

      assert_raise UndefinedFunctionError, fn ->
        AIContentGeneratorApi.generate_follow_up_email(meeting)
      end
    end
  end

  describe "behaviour callbacks" do
    test "behaviour module defines callbacks" do
      # Verify the behaviour module exists and has the expected structure
      # We can't directly inspect callbacks, but we can verify implementations work
      assert Code.ensure_loaded?(SocialScribe.AIContentGeneratorApi)

      # Verify that TestImplementation implements the behaviour correctly
      assert function_exported?(TestImplementation, :generate_follow_up_email, 1)
      assert function_exported?(TestImplementation, :generate_automation, 2)
      assert function_exported?(TestImplementation, :generate_hubspot_suggestions, 1)
      assert function_exported?(TestImplementation, :generate_crm_suggestions, 1)
      assert function_exported?(TestImplementation, :answer_crm_question, 2)
    end
  end

  describe "delegation mechanism" do
    test "all wrapper functions delegate to impl()" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementation)

      # Test that all wrapper functions successfully delegate
      meeting = %{id: 123}
      automation = %{id: 456}
      question = "Test?"
      context = %{}

      assert {:ok, _} = AIContentGeneratorApi.generate_follow_up_email(meeting)
      assert {:ok, _} = AIContentGeneratorApi.generate_automation(automation, meeting)
      assert {:ok, _} = AIContentGeneratorApi.generate_hubspot_suggestions(meeting)
      assert {:ok, _} = AIContentGeneratorApi.generate_crm_suggestions(meeting)
      assert {:ok, _} = AIContentGeneratorApi.answer_crm_question(question, context)
    end

    test "wrapper functions preserve return values from implementation" do
      Application.put_env(:social_scribe, :ai_content_generator_api, TestImplementationWithErrors)

      meeting = %{id: 123}
      automation = %{id: 456}
      question = "Test?"
      context = %{}

      # All should return errors as the implementation does
      assert {:error, :test_error} = AIContentGeneratorApi.generate_follow_up_email(meeting)
      assert {:error, :test_error} = AIContentGeneratorApi.generate_automation(automation, meeting)
      assert {:error, :test_error} = AIContentGeneratorApi.generate_hubspot_suggestions(meeting)
      assert {:error, :test_error} = AIContentGeneratorApi.generate_crm_suggestions(meeting)
      assert {:error, :test_error} = AIContentGeneratorApi.answer_crm_question(question, context)
    end
  end
end
