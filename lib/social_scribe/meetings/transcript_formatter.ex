defmodule SocialScribe.Meetings.TranscriptFormatter do
  @moduledoc """
  Formats meeting transcripts for display and AI prompts.
  """

  alias SocialScribe.Meetings.MeetingTranscript

  @doc """
  Converts a MeetingTranscript to a formatted string for prompts.

  Returns `{:ok, string}` or `{:error, :no_transcript}` if transcript is missing or empty.
  """
  @spec transcript_to_string(MeetingTranscript.t()) ::
          {:ok, String.t()} | {:error, :no_transcript}
  def transcript_to_string(%MeetingTranscript{content: %{"data" => transcript_data}})
      when not is_nil(transcript_data) do
    {:ok, format_transcript_for_prompt(transcript_data)}
  end

  def transcript_to_string(_), do: {:error, :no_transcript}

  @doc """
  Formats transcript segments into a readable string with timestamps and speaker names.
  """
  @spec format_transcript_for_prompt(list(map())) :: String.t()
  def format_transcript_for_prompt(transcript_segments) when is_list(transcript_segments) do
    Enum.map_join(transcript_segments, "\n", fn segment ->
      speaker = Map.get(segment, "speaker", "Unknown Speaker")
      words = Map.get(segment, "words", [])
      text = Enum.map_join(words, " ", &Map.get(&1, "text", ""))
      timestamp = format_timestamp(List.first(words))
      "[#{timestamp}] #{speaker}: #{text}"
    end)
  end

  def format_transcript_for_prompt(_), do: ""

  defp format_timestamp(nil), do: "00:00"

  defp format_timestamp(word) do
    seconds = extract_seconds(Map.get(word, "start_timestamp"))
    total_seconds = trunc(seconds)
    minutes = div(total_seconds, 60)
    secs = rem(total_seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  # Handle map format: %{"absolute" => "...", "relative" => 41.911842}
  defp extract_seconds(%{"relative" => relative}) when is_number(relative), do: relative
  # Handle direct float format: 0.48204318
  defp extract_seconds(seconds) when is_number(seconds), do: seconds
  defp extract_seconds(_), do: 0
end
