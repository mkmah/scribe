defmodule SocialScribe.AIContentGeneratorTest do
  use SocialScribe.DataCase, async: false

  alias SocialScribe.AIContentGenerator
  alias SocialScribe.Meetings

  import SocialScribe.MeetingsFixtures
  import SocialScribe.AutomationsFixtures

  defmodule TestLLMProvider do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt), do: {:ok, "Here is a follow-up email.\n\nBest regards"}
  end

  defmodule TestLLMProviderError do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt), do: {:error, :test}
  end

  defmodule TestLLMProviderJSON do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt) do
      json = """
      [
        {"field": "phone", "value": "555-1234", "context": "mentioned", "timestamp": "01:00"},
        {"field": "company", "value": "Acme", "context": "said", "timestamp": "02:00"}
      ]
      """

      {:ok, json}
    end
  end

  defmodule TestLLMProviderJSONWithBackticks do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt) do
      {:ok,
       "```json\n[{\"field\": \"email\", \"value\": \"a@b.com\", \"context\": \"x\", \"timestamp\": \"00:00\"}]\n```"}
    end
  end

  defmodule TestLLMProviderMarkdownJSON do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt) do
      json = """
      Here is the JSON you requested:
      ```json
      [
        {"field": "phone", "value": "555-5678", "context": "found", "timestamp": "03:00"}
      ]
      ```
      Hope that helps!
      """

      {:ok, json}
    end
  end

  defmodule TestLLMProviderEmptyArray do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt), do: {:ok, "[]"}
  end

  defmodule TestLLMProviderInvalidJSON do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt), do: {:ok, "not valid json"}
  end

  defmodule TestLLMProviderNonListJSON do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt), do: {:ok, "{\"foo\": 1}"}
  end

  defmodule TestLLMProviderSkipsNilFieldValue do
    @behaviour SocialScribe.LLM.Provider
    @impl true
    def complete(_prompt) do
      # One valid, one with nil field so filtered out
      json = """
      [
        {"field": "phone", "value": "555", "context": "c", "timestamp": "0"},
        {"field": null, "value": "x", "context": "c", "timestamp": "0"}
      ]
      """

      {:ok, json}
    end
  end

  setup do
    Application.put_env(:social_scribe, :llm_provider, TestLLMProvider)
    on_exit(fn -> Application.delete_env(:social_scribe, :llm_provider) end)
    :ok
  end

  defp meeting_with_transcript_and_participants do
    meeting = meeting_fixture()

    transcript_content = %{
      "data" => [
        %{"speaker" => "Alice", "words" => [%{"text" => "Hello"}, %{"text" => "everyone"}]}
      ]
    }

    meeting_transcript_fixture(%{meeting_id: meeting.id, content: transcript_content})
    meeting_participant_fixture(%{meeting_id: meeting.id})
    Meetings.get_meeting_with_details(meeting.id)
  end

  describe "generate_follow_up_email/1" do
    test "returns generated email when meeting has transcript and participants" do
      meeting = meeting_with_transcript_and_participants()
      assert {:ok, body} = AIContentGenerator.generate_follow_up_email(meeting)
      assert is_binary(body)
      assert body =~ "follow-up"
    end

    test "returns error when meeting has no participants" do
      meeting = meeting_fixture()
      transcript_content = %{"data" => [%{"speaker" => "A", "words" => [%{"text" => "hi"}]}]}
      meeting_transcript_fixture(%{meeting_id: meeting.id, content: transcript_content})
      meeting = Meetings.get_meeting_with_details(meeting.id)
      meeting = %{meeting | meeting_participants: []}

      assert {:error, :no_participants} = AIContentGenerator.generate_follow_up_email(meeting)
    end

    test "returns error when LLM fails" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderError)
      meeting = meeting_with_transcript_and_participants()
      assert {:error, :test} = AIContentGenerator.generate_follow_up_email(meeting)
    end
  end

  describe "generate_automation/2" do
    test "returns generated content when meeting and automation are valid" do
      meeting = meeting_with_transcript_and_participants()
      automation = automation_fixture(%{user_id: meeting.calendar_event.user_id})

      assert {:ok, body} = AIContentGenerator.generate_automation(automation, meeting)
      assert is_binary(body)
    end

    test "returns error when meeting has no participants" do
      meeting = meeting_fixture()
      transcript_content = %{"data" => [%{"speaker" => "A", "words" => [%{"text" => "hi"}]}]}
      meeting_transcript_fixture(%{meeting_id: meeting.id, content: transcript_content})
      meeting = Meetings.get_meeting_with_details(meeting.id)
      meeting = %{meeting | meeting_participants: []}
      automation = automation_fixture()

      assert {:error, :no_participants} =
               AIContentGenerator.generate_automation(automation, meeting)
    end

    test "returns error when LLM fails" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderError)
      meeting = meeting_with_transcript_and_participants()
      automation = automation_fixture()

      assert {:error, :test} = AIContentGenerator.generate_automation(automation, meeting)
    end
  end

  describe "generate_hubspot_suggestions/1" do
    test "returns parsed suggestions when LLM returns valid JSON array" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderJSON)
      meeting = meeting_with_transcript_and_participants()

      assert {:ok, suggestions} = AIContentGenerator.generate_hubspot_suggestions(meeting)
      assert length(suggestions) == 2
      assert Enum.at(suggestions, 0).field == "phone"
      assert Enum.at(suggestions, 0).value == "555-1234"
      assert Enum.at(suggestions, 1).field == "company"
    end

    test "strips ```json wrapper and parses" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderJSONWithBackticks)
      meeting = meeting_with_transcript_and_participants()

      assert {:ok, [s | _]} = AIContentGenerator.generate_hubspot_suggestions(meeting)
      assert s.field == "email"
      assert s.value == "a@b.com"
    end

    test "parses JSON embedded in markdown text" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderMarkdownJSON)
      meeting = meeting_with_transcript_and_participants()

      assert {:ok, [s | _]} = AIContentGenerator.generate_hubspot_suggestions(meeting)
      assert s.field == "phone"
      assert s.value == "555-5678"
    end

    test "returns empty list when LLM returns empty array" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderEmptyArray)
      meeting = meeting_with_transcript_and_participants()

      assert {:ok, []} = AIContentGenerator.generate_hubspot_suggestions(meeting)
    end

    test "returns error when LLM returns invalid JSON" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderInvalidJSON)
      meeting = meeting_with_transcript_and_participants()

      assert {:error, {:parsing_error, _}} =
               AIContentGenerator.generate_hubspot_suggestions(meeting)
    end

    test "returns error when meeting has no participants" do
      meeting = meeting_fixture()
      transcript_content = %{"data" => [%{"speaker" => "A", "words" => [%{"text" => "hi"}]}]}
      meeting_transcript_fixture(%{meeting_id: meeting.id, content: transcript_content})
      meeting = Meetings.get_meeting_with_details(meeting.id)
      meeting = %{meeting | meeting_participants: []}

      assert {:error, :no_participants} = AIContentGenerator.generate_hubspot_suggestions(meeting)
    end

    test "returns error when LLM fails" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderError)
      meeting = meeting_with_transcript_and_participants()

      assert {:error, :test} = AIContentGenerator.generate_hubspot_suggestions(meeting)
    end
  end

  describe "generate_crm_suggestions/1" do
    test "returns parsed suggestions when LLM returns valid JSON array" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderJSON)
      meeting = meeting_with_transcript_and_participants()

      assert {:ok, suggestions} = AIContentGenerator.generate_crm_suggestions(meeting)
      assert length(suggestions) == 2
      assert Enum.at(suggestions, 0).field == "phone"
    end

    test "returns empty list when LLM returns non-list JSON" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderNonListJSON)
      meeting = meeting_with_transcript_and_participants()

      assert {:ok, []} = AIContentGenerator.generate_crm_suggestions(meeting)
    end

    test "filters out entries with nil field or value" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderSkipsNilFieldValue)
      meeting = meeting_with_transcript_and_participants()

      assert {:ok, suggestions} = AIContentGenerator.generate_crm_suggestions(meeting)
      assert length(suggestions) == 1
      assert hd(suggestions).field == "phone"
    end

    test "returns error when LLM fails" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderError)
      meeting = meeting_with_transcript_and_participants()

      assert {:error, :test} = AIContentGenerator.generate_crm_suggestions(meeting)
    end
  end

  describe "answer_crm_question/2" do
    test "returns answer when LLM succeeds" do
      context = %{"question" => "Who attended?", "contacts" => []}

      assert {:ok, body} = AIContentGenerator.answer_crm_question("Who was there?", context)
      assert is_binary(body)
      assert body =~ "follow-up"
    end

    test "returns error when LLM fails" do
      Application.put_env(:social_scribe, :llm_provider, TestLLMProviderError)
      context = %{"question" => "x", "contacts" => []}

      assert {:error, :test} =
               AIContentGenerator.answer_crm_question("Who was there?", context)
    end
  end
end
