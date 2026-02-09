defmodule SocialScribe.Meetings.ParticipantParser do
  @moduledoc """
  Parses and formats meeting participant data.
  """

  alias SocialScribe.Meetings.Meeting
  alias SocialScribe.Meetings.MeetingParticipant

  @doc """
  Converts a list of participants to a formatted string for prompts.

  Returns `{:ok, string}` or `{:error, :no_participants}` if the list is empty.
  """
  @spec participants_to_string(list(MeetingParticipant.t())) ::
          {:ok, String.t()} | {:error, :no_participants}
  def participants_to_string(participants) when is_list(participants) do
    if Enum.empty?(participants) do
      {:error, :no_participants}
    else
      participants_string =
        participants
        |> Enum.map(fn participant ->
          role = if participant.is_host, do: "Host", else: "Participant"
          "#{participant.name} (#{role})"
        end)
        |> Enum.join("\n")

      {:ok, participants_string}
    end
  end

  def participants_to_string(_), do: {:error, :no_participants}

  @doc """
  Parses participant data from Recall.ai format into attributes for database insertion.
  """
  @spec parse_participant_attrs(Meeting.t(), map()) :: map()
  def parse_participant_attrs(meeting, participant_data) do
    %{
      meeting_id: meeting.id,
      recall_participant_id: to_string(participant_data.id),
      name: participant_data.name,
      is_host: Map.get(participant_data, :is_host, false)
    }
  end

  @doc """
  Parses and deduplicates participants data from Recall.ai API response.
  """
  @spec parse_participants_data(any()) :: list(map())
  def parse_participants_data(participants_data) do
    case participants_data do
      data when is_list(data) ->
        Enum.uniq_by(data, & &1[:id])

      _ ->
        []
    end
  end
end
