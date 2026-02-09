defmodule SocialScribe.Workers.BotStatusPoller do
  @moduledoc """
  Oban worker that polls Recall.ai API for bot status updates.

  This is kept as a fallback mechanism in case webhooks fail or are not configured.
  Runs less frequently than before (every 30 minutes) since webhooks handle real-time updates.
  """

  use Oban.Worker, queue: :polling, max_attempts: 3

  alias SocialScribe.Bots
  alias SocialScribe.Bots.Processor
  alias SocialScribe.RecallApi

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    bots_to_poll = Bots.list_pending_bots()

    if Enum.any?(bots_to_poll) do
      Logger.info("Polling #{Enum.count(bots_to_poll)} pending Recall.ai bots...")
    end

    for bot_record <- bots_to_poll do
      poll_and_process_bot(bot_record)
    end

    :ok
  end

  defp poll_and_process_bot(bot_record) do
    case RecallApi.get_bot(bot_record.recall_bot_id) do
      {:ok, %Tesla.Env{body: bot_api_info}} ->
        new_status =
          bot_api_info
          |> Map.get(:status_changes)
          |> List.last()
          |> Map.get(:code)

        Processor.handle_bot_status_change(bot_record, new_status, bot_api_info)

      {:error, reason} ->
        Logger.error(
          "Failed to poll bot status for #{bot_record.recall_bot_id}: #{inspect(reason)}"
        )

        Bots.update_recall_bot(bot_record, %{status: "polling_error"})
    end
  end
end
