defmodule SocialScribe.Bots.ProcessorTest do
  use SocialScribe.DataCase, async: true

  import Mox
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.BotsFixtures
  import SocialScribe.MeetingInfoExample
  import SocialScribe.MeetingTranscriptExample

  alias SocialScribe.Bots
  alias SocialScribe.Bots.Processor
  alias SocialScribe.Meetings
  alias SocialScribe.RecallApiMock
  alias SocialScribe.AIContentGeneratorMock

  setup :verify_on_exit!

  setup do
    stub_with(RecallApiMock, SocialScribe.Recall)
    stub_with(AIContentGeneratorMock, SocialScribe.AIContentGenerator)
    :ok
  end

  describe "handle_bot_status_change/3" do
    test "updates bot status and processes completion when status is 'done'" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-processor-123",
          status: "in_call_recording"
        })

      bot_api_info = meeting_info_example(%{id: "bot-processor-123"})

      expect(RecallApiMock, :get_bot_transcript, fn "bot-processor-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-processor-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Test User", is_host: true}
           ]
         }}
      end)

      assert Processor.handle_bot_status_change(bot_record, "done", bot_api_info) == :ok

      # Verify bot status was updated
      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "done"

      # Verify meeting was created
      meeting = Meetings.get_meeting_by_recall_bot_id(updated_bot.id)
      assert meeting != nil

      # Verify AI content generation was enqueued
      assert_enqueued(
        worker: SocialScribe.Workers.AIContentGenerationWorker,
        args: %{"meeting_id" => meeting.id}
      )
    end

    test "updates bot status but does not process completion when status is not 'done'" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-processor-456",
          status: "ready"
        })

      assert Processor.handle_bot_status_change(bot_record, "in_call_recording", nil) == :ok

      # Verify bot status was updated
      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "in_call_recording"

      # Verify no meeting was created
      assert Meetings.get_meeting_by_recall_bot_id(updated_bot.id) == nil
    end

    test "does not re-process bot that already has a meeting" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-processor-789",
          status: "done"
        })

      # Pre-create a meeting for this bot
      Meetings.create_meeting_from_recall_data(
        bot_record,
        meeting_info_example(%{id: "bot-processor-789"}),
        meeting_transcript_example(),
        [%{id: 100, name: "Test User", is_host: true}]
      )

      bot_api_info = meeting_info_example(%{id: "bot-processor-789"})

      # Should NOT expect get_bot_transcript to be called
      # (Mox will fail if unexpected calls are made)

      assert Processor.handle_bot_status_change(bot_record, "done", bot_api_info) == :ok

      # Verify no duplicate meetings were created
      meetings_count =
        Meetings.list_meetings()
        |> Enum.filter(fn m -> m.recall_bot_id == bot_record.id end)
        |> length()

      assert meetings_count == 1
    end

    test "fetches bot info if not provided when status is 'done'" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-processor-fetch-123",
          status: "in_call_recording"
        })

      bot_api_info = meeting_info_example(%{id: "bot-processor-fetch-123"})

      # Expect get_bot to be called when bot_api_info is nil
      expect(RecallApiMock, :get_bot, fn "bot-processor-fetch-123" ->
        {:ok, %Tesla.Env{body: bot_api_info}}
      end)

      expect(RecallApiMock, :get_bot_transcript, fn "bot-processor-fetch-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-processor-fetch-123" ->
        {:ok, %Tesla.Env{body: []}}
      end)

      assert Processor.handle_bot_status_change(bot_record, "done", nil) == :ok

      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "done"
    end
  end

  describe "process_completed_bot/2" do
    test "successfully processes completed bot and creates meeting" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-completed-123",
          status: "done"
        })

      bot_api_info = meeting_info_example(%{id: "bot-completed-123"})

      expect(RecallApiMock, :get_bot_transcript, fn "bot-completed-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-completed-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Alice", is_host: true},
             %{id: 101, name: "Bob", is_host: false}
           ]
         }}
      end)

      Processor.process_completed_bot(bot_record, bot_api_info)

      # Verify meeting was created
      meeting = Meetings.get_meeting_by_recall_bot_id(bot_record.id)
      assert meeting != nil
      assert meeting.title == calendar_event.summary

      # Verify participants were created
      participants =
        Repo.all(
          from p in Meetings.MeetingParticipant,
            where: p.meeting_id == ^meeting.id
        )

      assert Enum.count(participants) == 2

      # Verify AI content generation was enqueued
      assert_enqueued(
        worker: SocialScribe.Workers.AIContentGenerationWorker,
        args: %{"meeting_id" => meeting.id}
      )
    end

    test "handles transcript fetch failure gracefully" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-transcript-error",
          status: "done"
        })

      bot_api_info = meeting_info_example(%{id: "bot-transcript-error"})

      expect(RecallApiMock, :get_bot_transcript, fn "bot-transcript-error" ->
        {:error, :transcript_fetch_failed}
      end)

      Processor.process_completed_bot(bot_record, bot_api_info)

      # Verify no meeting was created
      assert Meetings.get_meeting_by_recall_bot_id(bot_record.id) == nil
    end
  end

  describe "fetch_participants/1" do
    test "successfully fetches participants" do
      expect(RecallApiMock, :get_bot_participants, fn "bot-participants-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Alice", is_host: true},
             %{id: 101, name: "Bob", is_host: false}
           ]
         }}
      end)

      assert {:ok, participants} = Processor.fetch_participants("bot-participants-123")
      assert length(participants) == 2
    end

    test "returns empty list on fetch failure" do
      expect(RecallApiMock, :get_bot_participants, fn "bot-participants-error" ->
        {:error, :fetch_failed}
      end)

      assert {:ok, []} = Processor.fetch_participants("bot-participants-error")
    end
  end
end
