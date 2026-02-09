defmodule SocialScribe.Bots.Processor do
  @moduledoc """
  Shared module for processing bot status changes and handling bot completion.

  Used by both the webhook controller and the poller worker.
  """

  alias SocialScribe.Bots
  alias SocialScribe.RecallApi
  alias SocialScribe.Meetings
  alias SocialScribe.Bots.RecallBot

  require Logger

  @doc """
  Handles a bot status change event.

  Updates the bot status in the database and processes completion if the bot is done.

  ## Parameters
  - `bot_record` - The RecallBot record from the database
  - `status` - The new status code (e.g., "done", "fatal")
  - `bot_api_info` - Optional bot info from Recall API (used when processing completion)

  ## Returns
  - `:ok` - Status updated successfully
  - `{:error, reason}` - Error updating status
  """
  def handle_bot_status_change(%RecallBot{} = bot_record, status, bot_api_info \\ nil) do
    {:ok, updated_bot_record} = Bots.update_recall_bot(bot_record, %{status: status})

    if status == "done" &&
         is_nil(Meetings.get_meeting_by_recall_bot_id(updated_bot_record.id)) do
      # Fetch bot info if not provided
      bot_info =
        bot_api_info ||
          case RecallApi.get_bot(bot_record.recall_bot_id) do
            {:ok, %Tesla.Env{body: info}} ->
              info

            {:error, reason} ->
              Logger.error(
                "Failed to fetch bot info for #{bot_record.recall_bot_id}: #{inspect(reason)}"
              )

              nil
          end

      if bot_info do
        process_completed_bot(updated_bot_record, bot_info)
      end
    else
      if status != bot_record.status do
        Logger.info("Bot #{bot_record.recall_bot_id} status updated to: #{status}")
      end
    end

    :ok
  end

  @doc """
  Processes a completed bot by fetching transcript and participants, then creating a meeting record.

  This function:
  1. Fetches the transcript from Recall API
  2. Fetches participants data
  3. Creates a meeting record with transcript and participants
  4. Enqueues AI content generation worker
  """
  def process_completed_bot(%RecallBot{} = bot_record, bot_api_info) do
    Logger.info(
      "Bot #{bot_record.recall_bot_id} is done. Fetching transcript and participants..."
    )

    with {:ok, %Tesla.Env{body: transcript_data}} <-
           RecallApi.get_bot_transcript(bot_record.recall_bot_id),
         {:ok, participants_data} <- fetch_participants(bot_record.recall_bot_id) do
      Logger.info(
        "Successfully fetched transcript and participants for bot #{bot_record.recall_bot_id}"
      )

      case Meetings.create_meeting_from_recall_data(
             bot_record,
             bot_api_info,
             transcript_data,
             participants_data
           ) do
        {:ok, meeting} ->
          Logger.info(
            "Successfully created meeting record #{meeting.id} from bot #{bot_record.recall_bot_id}"
          )

          SocialScribe.Workers.AIContentGenerationWorker.new(%{meeting_id: meeting.id})
          |> Oban.insert()

          Logger.info("Enqueued AI content generation for meeting #{meeting.id}")

        {:error, reason} ->
          Logger.error(
            "Failed to create meeting record from bot #{bot_record.recall_bot_id}: #{inspect(reason)}"
          )
      end
    else
      {:error, reason} ->
        Logger.error(
          "Failed to fetch data for bot #{bot_record.recall_bot_id} after completion: #{inspect(reason)}"
        )
    end
  end

  @doc """
  Fetches participants data for a bot.

  Returns an empty list if fetching fails (non-critical).
  """
  def fetch_participants(recall_bot_id) do
    case RecallApi.get_bot_participants(recall_bot_id) do
      {:ok, %Tesla.Env{body: participants_data}} ->
        {:ok, participants_data}

      {:error, reason} ->
        Logger.warning(
          "Could not fetch participants for bot #{recall_bot_id}: #{inspect(reason)}, falling back to empty list"
        )

        {:ok, []}
    end
  end
end
