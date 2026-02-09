defmodule SocialScribe.Meetings.PromptBuilder do
  @moduledoc """
  Builds prompts for AI content generation from meeting data.
  """

  alias SocialScribe.Meetings.Meeting
  alias SocialScribe.Meetings.ParticipantParser
  alias SocialScribe.Meetings.TranscriptFormatter

  @doc """
  Generates a prompt for a meeting that can be used for AI content generation.

  Returns `{:ok, prompt_string}` or `{:error, reason}` if meeting data is incomplete.
  """
  @spec generate_prompt_for_meeting(Meeting.t()) :: {:ok, String.t()} | {:error, atom()}
  def generate_prompt_for_meeting(%Meeting{} = meeting) do
    with {:ok, participants_string} <-
           ParticipantParser.participants_to_string(meeting.meeting_participants),
         {:ok, transcript_string} <-
           TranscriptFormatter.transcript_to_string(meeting.meeting_transcript) do
      {:ok,
       build_prompt(
         meeting.title,
         meeting.recorded_at,
         meeting.duration_seconds,
         participants_string,
         transcript_string
       )}
    end
  end

  defp build_prompt(title, date, duration, participants, transcript) do
    """
    ## Meeting Info:
    title: #{title}
    date: #{date}
    duration: #{duration} seconds

    ### Participants:
    #{participants}

    ### Transcript:
    #{transcript}
    """
  end
end
