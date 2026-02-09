defmodule SocialScribe.Meetings.Crm do
  @moduledoc """
  CRM-related functions for meetings, including auto-detection of CRM providers.
  """

  alias SocialScribe.Meetings.Meeting
  alias SocialScribe.Accounts
  alias SocialScribe.Crm.Registry
  alias SocialScribe.Repo

  require Logger

  @doc """
  Attempts to auto-detect which CRM provider should be associated with a meeting
  by searching for meeting participants in the user's connected CRMs.

  Returns:
  - `{:ok, provider}` if exactly one CRM has matching contacts
  - `{:multiple_matches, providers}` if multiple CRMs have matches
  - `{:no_matches}` if no matches found or no CRMs connected
  """
  @spec auto_detect_crm_provider(Meeting.t()) ::
          {:ok, String.t()} | {:multiple_matches, list(String.t())} | {:no_matches}
  def auto_detect_crm_provider(%Meeting{} = meeting) do
    # Ensure meeting is preloaded with necessary associations
    meeting =
      if Ecto.assoc_loaded?(meeting.meeting_participants) &&
           Ecto.assoc_loaded?(meeting.calendar_event) do
        meeting
      else
        Repo.preload(meeting, [:meeting_participants, calendar_event: []])
      end

    user_id = meeting.calendar_event.user_id

    if is_nil(user_id) do
      {:no_matches}
    else
      participant_names =
        meeting.meeting_participants
        |> Enum.map(& &1.name)
        |> Enum.filter(&(&1 && String.trim(&1) != ""))

      if Enum.empty?(participant_names) do
        {:no_matches}
      else
        detect_from_participants(user_id, participant_names)
      end
    end
  end

  defp detect_from_participants(user_id, participant_names) do
    # Get all connected CRM credentials for the user
    connected_crms =
      Registry.crm_providers()
      |> Enum.map(fn provider ->
        case Accounts.get_user_crm_credential(user_id, provider) do
          nil -> nil
          credential -> {provider, credential}
        end
      end)
      |> Enum.filter(&(&1 != nil))

    if Enum.empty?(connected_crms) do
      {:no_matches}
    else
      # Search for each participant name in each CRM
      matches_per_provider =
        Enum.reduce(participant_names, %{}, fn name, acc ->
          Enum.reduce(connected_crms, acc, fn {provider, credential}, provider_acc ->
            case search_contact_in_crm(provider, credential, name) do
              {:ok, contacts} when contacts != [] ->
                Map.update(provider_acc, provider, 1, &(&1 + 1))

              _ ->
                provider_acc
            end
          end)
        end)

      case Map.keys(matches_per_provider) do
        [single_provider] ->
          {:ok, single_provider}

        [] ->
          {:no_matches}

        multiple_providers ->
          {:multiple_matches, multiple_providers}
      end
    end
  end

  defp search_contact_in_crm(provider, credential, query) do
    case Registry.adapter_for(provider) do
      {:ok, adapter} ->
        adapter.search_contacts(credential, query)

      {:error, _} ->
        {:error, :unknown_provider}
    end
  end
end
