defmodule SocialScribe.Crm.Suggestions do
  @moduledoc """
  Provider-agnostic CRM suggestion generation and merging.

  Uses canonical field names so the same AI prompt and merging logic
  works for any CRM provider.
  """

  alias SocialScribe.Crm.Contact

  @field_labels %{
    "first_name" => "First Name",
    "last_name" => "Last Name",
    "email" => "Email",
    "phone" => "Phone",
    "mobile_phone" => "Mobile Phone",
    "company" => "Company",
    "job_title" => "Job Title",
    "address" => "Address",
    "city" => "City",
    "state" => "State",
    "zip" => "ZIP Code",
    "country" => "Country",
    "website" => "Website",
    "linkedin_url" => "LinkedIn",
    "twitter_handle" => "Twitter"
  }

  @doc """
  Returns the human-readable label for a canonical field name.
  Falls back to the field name itself for unknown fields.
  """
  @spec field_label(String.t()) :: String.t()
  def field_label(field_name) when is_binary(field_name) do
    Map.get(@field_labels, field_name, field_name)
  end

  @doc """
  Generates suggestions from a meeting transcript using AI.
  Returns suggestions with canonical field names.
  """
  @spec generate_from_meeting(map()) :: {:ok, list(map())} | {:error, any()}
  def generate_from_meeting(meeting) do
    case ai_impl().generate_crm_suggestions(meeting) do
      {:ok, ai_suggestions} ->
        suggestions =
          ai_suggestions
          |> Enum.map(fn suggestion ->
            %{
              field: suggestion.field,
              label: field_label(suggestion.field),
              current_value: nil,
              new_value: suggestion.value,
              context: Map.get(suggestion, :context),
              timestamp: Map.get(suggestion, :timestamp),
              apply: true,
              has_change: true
            }
          end)

        {:ok, suggestions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Merges AI suggestions with a Contact to show current vs suggested values.
  Filters out suggestions where new_value matches current_value.
  Deduplicates by field (keeps first suggestion per field) so the same field
  is not shown multiple times when the AI returns duplicates.
  Marks all remaining suggestions with apply: true.
  """
  @spec merge_with_contact(list(map()), Contact.t()) :: list(map())
  def merge_with_contact(suggestions, %Contact{} = contact) when is_list(suggestions) do
    suggestions
    |> Enum.map(fn suggestion ->
      current_value = Contact.get_field(contact, suggestion.field)

      %{
        suggestion
        | current_value: current_value,
          has_change: current_value != suggestion.new_value,
          apply: true
      }
    end)
    |> Enum.filter(& &1.has_change)
    |> deduplicate_by_field()
  end

  # Keeps first suggestion per field so we never show duplicate field cards.
  defp deduplicate_by_field(suggestions) do
    suggestions
    |> Enum.reduce({[], MapSet.new()}, fn suggestion, {acc, seen} ->
      field_key = to_string(suggestion.field)

      if MapSet.member?(seen, field_key) do
        {acc, seen}
      else
        {[suggestion | acc], MapSet.put(seen, field_key)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp ai_impl do
    Application.get_env(
      :social_scribe,
      :ai_content_generator_api,
      SocialScribe.AIContentGenerator
    )
  end
end
