defmodule SocialScribe.Crm.SuggestionsTest do
  use SocialScribe.DataCase

  alias SocialScribe.Crm.Suggestions
  alias SocialScribe.Crm.Contact

  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import Mox

  setup :verify_on_exit!

  describe "generate_from_meeting/1" do
    test "returns suggestions with canonical field names from AI" do
      meeting = meeting_fixture_with_transcript()

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_suggestions, fn _meeting ->
        {:ok,
         [
           %{field: "phone", value: "555-1234", context: "Mentioned phone", timestamp: "01:23"},
           %{field: "company", value: "Acme Corp", context: "Works at Acme", timestamp: "05:47"}
         ]}
      end)

      assert {:ok, suggestions} = Suggestions.generate_from_meeting(meeting)
      assert length(suggestions) == 2

      phone_suggestion = Enum.find(suggestions, &(&1.field == "phone"))
      assert phone_suggestion.new_value == "555-1234"
      assert phone_suggestion.label == "Phone"
      assert phone_suggestion.context == "Mentioned phone"
      assert phone_suggestion.timestamp == "01:23"
      assert phone_suggestion.apply == true
      assert phone_suggestion.has_change == true
    end

    test "returns empty list when AI finds no suggestions" do
      meeting = meeting_fixture_with_transcript()

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_suggestions, fn _meeting ->
        {:ok, []}
      end)

      assert {:ok, []} = Suggestions.generate_from_meeting(meeting)
    end

    test "returns error when AI call fails" do
      meeting = meeting_fixture_with_transcript()

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_suggestions, fn _meeting ->
        {:error, {:api_error, 500, "Internal server error"}}
      end)

      assert {:error, _} = Suggestions.generate_from_meeting(meeting)
    end
  end

  describe "merge_with_contact/2" do
    test "sets current_value from contact for each suggestion" do
      contact =
        Contact.new(%{
          id: "123",
          phone: "555-0000",
          company: "Old Corp",
          email: "test@example.com"
        })

      suggestions = [
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "Mentioned phone",
          timestamp: "01:23",
          apply: true,
          has_change: true
        },
        %{
          field: "company",
          label: "Company",
          current_value: nil,
          new_value: "Acme Corp",
          context: "Works at Acme",
          timestamp: "05:47",
          apply: true,
          has_change: true
        }
      ]

      result = Suggestions.merge_with_contact(suggestions, contact)

      phone = Enum.find(result, &(&1.field == "phone"))
      assert phone.current_value == "555-0000"
      assert phone.new_value == "555-1234"

      company = Enum.find(result, &(&1.field == "company"))
      assert company.current_value == "Old Corp"
      assert company.new_value == "Acme Corp"
    end

    test "filters out suggestions where new_value matches current_value" do
      contact = Contact.new(%{id: "123", company: "Acme Corp", phone: nil})

      suggestions = [
        %{
          field: "company",
          label: "Company",
          current_value: nil,
          new_value: "Acme Corp",
          context: "Same company",
          timestamp: nil,
          apply: true,
          has_change: true
        },
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "New phone",
          timestamp: nil,
          apply: true,
          has_change: true
        }
      ]

      result = Suggestions.merge_with_contact(suggestions, contact)

      assert length(result) == 1
      assert hd(result).field == "phone"
    end

    test "marks all remaining suggestions with apply: true" do
      contact = Contact.new(%{id: "123", phone: nil})

      suggestions = [
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "test",
          timestamp: nil,
          apply: false,
          has_change: true
        }
      ]

      result = Suggestions.merge_with_contact(suggestions, contact)

      assert hd(result).apply == true
    end

    test "handles empty suggestions list" do
      contact = Contact.new(%{id: "123", email: "test@example.com"})

      assert [] = Suggestions.merge_with_contact([], contact)
    end

    test "handles contact with nil fields" do
      contact = Contact.new(%{id: "123"})

      suggestions = [
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "test",
          timestamp: nil,
          apply: true,
          has_change: true
        }
      ]

      result = Suggestions.merge_with_contact(suggestions, contact)

      assert length(result) == 1
      assert hd(result).current_value == nil
      assert hd(result).new_value == "555-1234"
    end
  end

  describe "field_label/1" do
    test "returns human-readable label for canonical field names" do
      assert Suggestions.field_label("first_name") == "First Name"
      assert Suggestions.field_label("last_name") == "Last Name"
      assert Suggestions.field_label("email") == "Email"
      assert Suggestions.field_label("phone") == "Phone"
      assert Suggestions.field_label("mobile_phone") == "Mobile Phone"
      assert Suggestions.field_label("company") == "Company"
      assert Suggestions.field_label("job_title") == "Job Title"
      assert Suggestions.field_label("address") == "Address"
      assert Suggestions.field_label("city") == "City"
      assert Suggestions.field_label("state") == "State"
      assert Suggestions.field_label("zip") == "ZIP Code"
      assert Suggestions.field_label("country") == "Country"
      assert Suggestions.field_label("website") == "Website"
      assert Suggestions.field_label("linkedin_url") == "LinkedIn"
      assert Suggestions.field_label("twitter_handle") == "Twitter"
    end

    test "returns the field name itself for unknown fields" do
      assert Suggestions.field_label("custom_field") == "custom_field"
    end
  end

  # Helper to create a meeting with transcript for testing
  defp meeting_fixture_with_transcript do
    user = user_fixture()
    meeting = meeting_fixture(%{})

    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)
    {:ok, _} = SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "John Doe",
            "words" => [
              %{"text" => "My"},
              %{"text" => "phone"},
              %{"text" => "is"},
              %{"text" => "555-1234"}
            ]
          }
        ]
      }
    })

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end
end
