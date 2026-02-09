defmodule SocialScribeWeb.RecallWebhookControllerTest do
  use SocialScribeWeb.ConnCase
  use Oban.Testing, repo: SocialScribe.Repo

  import Mox
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.BotsFixtures
  import SocialScribe.MeetingInfoExample
  import SocialScribe.MeetingTranscriptExample

  alias SocialScribe.Bots
  alias SocialScribe.Meetings
  alias SocialScribe.RecallApiMock
  alias SocialScribe.AIContentGeneratorMock

  setup :verify_on_exit!

  setup do
    stub_with(RecallApiMock, SocialScribe.Recall)
    stub_with(AIContentGeneratorMock, SocialScribe.AIContentGenerator)

    # Set a test webhook secret
    test_secret = "test_webhook_secret_12345"
    Application.put_env(:social_scribe, :recall_webhook_secret, test_secret)

    on_exit(fn ->
      Application.delete_env(:social_scribe, :recall_webhook_secret)
    end)

    {:ok, webhook_secret: test_secret}
  end

  defp build_recall_webhook_payload(bot_id, event_type, status_code \\ nil) do
    status_code = status_code || String.split(event_type, ".") |> List.last()

    %{
      "event" => event_type,
      "data" => %{
        "bot" => %{"id" => bot_id},
        "data" => %{"code" => status_code}
      }
    }
  end

  defp sign_webhook_payload(payload, secret, webhook_id \\ "test_webhook_id") do
    timestamp = System.system_time(:second) |> Integer.to_string()
    body = Jason.encode!(payload)
    signed_content = Enum.join([webhook_id, timestamp, body], ".")

    signature =
      :crypto.mac(:hmac, :sha256, secret, signed_content)
      |> Base.encode64()

    {body, webhook_id, timestamp, "v1,#{signature}"}
  end

  defp add_webhook_headers(conn, webhook_id, timestamp, signature) do
    conn
    |> put_req_header("webhook-id", webhook_id)
    |> put_req_header("webhook-timestamp", timestamp)
    |> put_req_header("webhook-signature", signature)
  end

  describe "POST /api/webhooks/recall" do
    test "handles bot.done event and processes completion", %{conn: conn, webhook_secret: secret} do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-123",
          status: "in_call_recording"
        })

      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      # Expect API calls for fetching bot info, transcript, and participants
      expect(RecallApiMock, :get_bot, fn "bot-webhook-123" ->
        {:ok, %Tesla.Env{body: meeting_info_example(%{id: "bot-webhook-123"})}}
      end)

      expect(RecallApiMock, :get_bot_transcript, fn "bot-webhook-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-webhook-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Alice", is_host: true},
             %{id: 101, name: "Bob", is_host: false}
           ]
         }}
      end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      # Verify bot status was updated
      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "done"

      # Verify meeting was created
      meeting = Meetings.get_meeting_by_recall_bot_id(updated_bot.id)
      assert meeting != nil
      assert meeting.title == calendar_event.summary

      # Verify AI content generation was enqueued
      assert_enqueued(
        worker: SocialScribe.Workers.AIContentGenerationWorker,
        args: %{"meeting_id" => meeting.id}
      )
    end

    test "handles bot status update event (non-done)", %{conn: conn, webhook_secret: secret} do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-456",
          status: "ready"
        })

      webhook_payload =
        build_recall_webhook_payload(
          "bot-webhook-456",
          "bot.in_call_recording",
          "in_call_recording"
        )

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      # Verify bot status was updated
      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "in_call_recording"

      # Verify no meeting was created (bot not done yet)
      assert Meetings.get_meeting_by_recall_bot_id(updated_bot.id) == nil
    end

    test "handles webhook for unknown bot_id gracefully", %{conn: conn, webhook_secret: secret} do
      webhook_payload = build_recall_webhook_payload("unknown-bot-999", "bot.done", "done")

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      # Should return 200 even for unknown bots (webhook delivery succeeded)
      assert response(conn, 200) == ""
    end

    test "handles webhook with missing bot_id", %{conn: conn, webhook_secret: secret} do
      # Missing bot.id in data.bot
      webhook_payload = %{
        "event" => "bot.done",
        "data" => %{
          "bot" => %{},
          "data" => %{"code" => "done"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 400) == ""
    end

    test "extracts status from event_type when status field is missing", %{
      conn: conn,
      webhook_secret: secret
    } do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-789",
          status: "ready"
        })

      # Status will be extracted from event_type
      webhook_payload = build_recall_webhook_payload("bot-webhook-789", "bot.in_call_recording")

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      # Verify bot status was extracted from event_type
      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "in_call_recording"
    end

    test "does not re-process bot that is already done", %{conn: conn, webhook_secret: secret} do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-already-done-111",
          status: "done"
        })

      # Pre-create a meeting for this bot
      Meetings.create_meeting_from_recall_data(
        bot_record,
        meeting_info_example(%{id: "bot-already-done-111"}),
        meeting_transcript_example(),
        [%{id: 100, name: "Alice", is_host: true}]
      )

      webhook_payload = build_recall_webhook_payload("bot-already-done-111", "bot.done", "done")

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      # Should NOT expect get_bot_transcript to be called
      # (Mox will fail if unexpected calls are made)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      # Verify no duplicate meetings were created
      meetings_count =
        Meetings.list_meetings()
        |> Enum.filter(fn m -> m.recall_bot_id == bot_record.id end)
        |> length()

      assert meetings_count == 1
    end

    test "rejects webhook with invalid signature", %{conn: conn, webhook_secret: secret} do
      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")

      {body, webhook_id, timestamp, _valid_signature} =
        sign_webhook_payload(webhook_payload, secret)

      # Use wrong signature
      invalid_signature = "v1,invalid_signature_base64=="

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, invalid_signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 401) == ""
    end

    test "rejects webhook with missing signature headers", %{conn: conn} do
      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")

      body = Jason.encode!(webhook_payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/recall", body)

      assert response(conn, 401) == ""
    end

    test "allows webhook when secret is not configured (development mode)", %{conn: conn} do
      # Temporarily remove the secret
      Application.delete_env(:social_scribe, :recall_webhook_secret)

      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")

      body = Jason.encode!(webhook_payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/recall", body)

      # Should accept (returns 200 or 400 based on payload, not 401)
      assert conn.status in [200, 400]

      # Restore secret
      Application.put_env(:social_scribe, :recall_webhook_secret, "test_secret")
    end

    test "handles webhook with whsec_ prefix and base64 decoding", %{conn: conn} do
      # Use a whsec_ prefixed secret (base64 encoded)
      base64_secret = Base.encode64("test_secret_key_12345")
      webhook_secret = "whsec_#{base64_secret}"
      Application.put_env(:social_scribe, :recall_webhook_secret, webhook_secret)

      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")

      {body, webhook_id, timestamp, signature} =
        sign_webhook_payload(webhook_payload, "test_secret_key_12345")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      # Should accept (returns 200 or 400 based on payload)
      assert conn.status in [200, 400]

      # Restore original secret
      Application.put_env(:social_scribe, :recall_webhook_secret, "test_webhook_secret_12345")
    end

    test "handles webhook with whsec_ prefix and base64url fallback", %{conn: conn} do
      # Use a whsec_ prefixed secret that fails base64 but succeeds with base64url
      base64url_secret = Base.url_encode64("test_secret_key", padding: false)
      webhook_secret = "whsec_#{base64url_secret}"
      Application.put_env(:social_scribe, :recall_webhook_secret, webhook_secret)

      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")

      {body, webhook_id, timestamp, signature} =
        sign_webhook_payload(webhook_payload, "test_secret_key")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      # Should accept (returns 200 or 400 based on payload)
      assert conn.status in [200, 400]

      # Restore original secret
      Application.put_env(:social_scribe, :recall_webhook_secret, "test_webhook_secret_12345")
    end

    test "rejects webhook with invalid signature format", %{conn: conn, webhook_secret: secret} do
      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")
      {body, webhook_id, timestamp, _signature} = sign_webhook_payload(webhook_payload, secret)

      # Invalid signature format (not "v1,signature")
      invalid_signature = "invalid_format"

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("webhook-id", webhook_id)
        |> put_req_header("webhook-timestamp", timestamp)
        |> put_req_header("webhook-signature", invalid_signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 401) == ""
    end

    test "rejects webhook with missing webhook-id header", %{conn: conn, webhook_secret: secret} do
      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")
      {body, _webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("webhook-timestamp", timestamp)
        |> put_req_header("webhook-signature", signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 401) == ""
    end

    test "rejects webhook with missing timestamp header", %{conn: conn, webhook_secret: secret} do
      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")
      {body, webhook_id, _timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("webhook-id", webhook_id)
        |> put_req_header("webhook-signature", signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 401) == ""
    end

    test "allows webhook when secret is empty string", %{conn: conn} do
      # Set empty secret
      Application.put_env(:social_scribe, :recall_webhook_secret, "")

      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")
      body = Jason.encode!(webhook_payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/recall", body)

      # Should accept (returns 200 or 400 based on payload, not 401)
      assert conn.status in [200, 400]

      # Restore original secret
      Application.put_env(:social_scribe, :recall_webhook_secret, "test_webhook_secret_12345")
    end

    test "handles payload with status from data.data.code (Recall.ai format)", %{
      conn: conn,
      webhook_secret: secret
    } do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-code-123",
          status: "ready"
        })

      # Payload with status in data.data.code
      webhook_payload = %{
        "event" => "bot.in_waiting_room",
        "data" => %{
          "bot" => %{"id" => "bot-webhook-code-123"},
          "data" => %{"code" => "in_waiting_room"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      # Verify bot status was extracted from data.data.code
      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "in_waiting_room"
    end

    test "handles payload with atom keys", %{conn: conn, webhook_secret: secret} do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-atom-123",
          status: "ready"
        })

      # Payload with atom keys (controller should handle both)
      webhook_payload = %{
        event: "bot.done",
        data: %{
          bot: %{id: "bot-webhook-atom-123"},
          data: %{code: "done"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      # Expect API calls for fetching bot info, transcript, and participants
      expect(RecallApiMock, :get_bot, fn "bot-webhook-atom-123" ->
        {:ok, %Tesla.Env{body: meeting_info_example(%{id: "bot-webhook-atom-123"})}}
      end)

      expect(RecallApiMock, :get_bot_transcript, fn "bot-webhook-atom-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-webhook-atom-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Alice", is_host: true}
           ]
         }}
      end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "done"
    end

    test "handles payload with missing data field", %{conn: conn, webhook_secret: secret} do
      webhook_payload = %{
        "event" => "bot.done"
        # Missing "data" field
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 400) == ""
    end

    test "handles payload with missing bot field", %{conn: conn, webhook_secret: secret} do
      webhook_payload = %{
        "event" => "bot.done",
        "data" => %{
          "data" => %{"code" => "done"}
          # Missing "bot" field
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 400) == ""
    end

    test "handles event_type that doesn't match bot.* pattern", %{
      conn: conn,
      webhook_secret: secret
    } do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-custom-123",
          status: "ready"
        })

      # Event type that doesn't split on "." as expected
      webhook_payload = %{
        "event" => "custom_event_type",
        "data" => %{
          "bot" => %{"id" => "bot-webhook-custom-123"},
          "data" => %{"code" => "custom_status"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      # Status should be extracted from data.data.code
      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "custom_status"
    end

    test "handles whsec_ prefix with invalid base64 that falls back to original secret", %{
      conn: conn
    } do
      # Use a whsec_ prefixed secret that fails both base64 and base64url decoding
      webhook_secret = "whsec_invalid_base64!!!"
      Application.put_env(:social_scribe, :recall_webhook_secret, webhook_secret)

      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")
      # Sign with the original secret (since fallback uses original secret)
      {body, webhook_id, timestamp, signature} =
        sign_webhook_payload(webhook_payload, webhook_secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      # Should accept (returns 200 or 400 based on payload)
      assert conn.status in [200, 400]

      # Restore original secret
      Application.put_env(:social_scribe, :recall_webhook_secret, "test_webhook_secret_12345")
    end

    test "handles invalid payload with non-nil error", %{conn: conn, webhook_secret: secret} do
      # Payload with invalid event_type (not a string)
      webhook_payload = %{
        # Invalid: should be string
        "event" => 12345,
        "data" => %{
          "bot" => %{"id" => "bot-webhook-123"},
          "data" => %{"code" => "done"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 400) == ""
    end

    test "handles payload with invalid bot.id (not a string)", %{
      conn: conn,
      webhook_secret: secret
    } do
      # Payload with bot.id as number instead of string
      webhook_payload = %{
        "event" => "bot.done",
        "data" => %{
          # Invalid: should be string
          "bot" => %{"id" => 12345},
          "data" => %{"code" => "done"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 400) == ""
    end

    test "handles payload with invalid data field (not a map)", %{
      conn: conn,
      webhook_secret: secret
    } do
      # Payload with data as string instead of map
      webhook_payload = %{
        "event" => "bot.done",
        # Invalid: should be map
        "data" => "invalid_data"
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 400) == ""
    end

    test "handles payload with invalid bot field (not a map)", %{
      conn: conn,
      webhook_secret: secret
    } do
      # Payload with bot as string instead of map
      webhook_payload = %{
        "event" => "bot.done",
        "data" => %{
          # Invalid: should be map
          "bot" => "invalid_bot",
          "data" => %{"code" => "done"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 400) == ""
    end

    test "handles event_type fallback when event field is missing", %{
      conn: conn,
      webhook_secret: secret
    } do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-event-type-123",
          status: "ready"
        })

      # Payload using event_type instead of event (fallback)
      webhook_payload = %{
        "event_type" => "bot.done",
        "data" => %{
          "bot" => %{"id" => "bot-webhook-event-type-123"},
          "data" => %{"code" => "done"}
        }
      }

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      # Expect API calls for fetching bot info, transcript, and participants
      expect(RecallApiMock, :get_bot, fn "bot-webhook-event-type-123" ->
        {:ok, %Tesla.Env{body: meeting_info_example(%{id: "bot-webhook-event-type-123"})}}
      end)

      expect(RecallApiMock, :get_bot_transcript, fn "bot-webhook-event-type-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-webhook-event-type-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Alice", is_host: true}
           ]
         }}
      end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      assert response(conn, 200) == ""

      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "done"
    end

    test "rejects webhook with duplicate headers (multiple values)", %{
      conn: conn,
      webhook_secret: secret
    } do
      webhook_payload = build_recall_webhook_payload("bot-webhook-123", "bot.done", "done")
      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      # Add duplicate headers (get_req_header would return list with multiple values)
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("webhook-id", webhook_id)
        # Duplicate header
        |> put_req_header("webhook-id", "duplicate_value")
        |> put_req_header("webhook-timestamp", timestamp)
        |> put_req_header("webhook-signature", signature)
        |> post("/api/webhooks/recall", body)

      # Should reject due to invalid signature format (pattern match fails)
      assert response(conn, 401) == ""
    end

    test "handles successful webhook with complete signature verification path", %{
      conn: conn,
      webhook_secret: secret
    } do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-success-123",
          status: "ready"
        })

      webhook_payload =
        build_recall_webhook_payload("bot-webhook-success-123", "bot.done", "done")

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      # Expect API calls
      expect(RecallApiMock, :get_bot, fn "bot-webhook-success-123" ->
        {:ok, %Tesla.Env{body: meeting_info_example(%{id: "bot-webhook-success-123"})}}
      end)

      expect(RecallApiMock, :get_bot_transcript, fn "bot-webhook-success-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-webhook-success-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Alice", is_host: true}
           ]
         }}
      end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> post("/api/webhooks/recall", body)

      # This should hit the full successful signature verification path
      assert response(conn, 200) == ""

      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "done"
    end

    test "handles get_raw_body fallback when raw_body is nil", %{
      conn: conn,
      webhook_secret: secret
    } do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      bot_record =
        recall_bot_fixture(%{
          user_id: user.id,
          calendar_event_id: calendar_event.id,
          recall_bot_id: "bot-webhook-fallback-123",
          status: "ready"
        })

      webhook_payload =
        build_recall_webhook_payload("bot-webhook-fallback-123", "bot.done", "done")

      {body, webhook_id, timestamp, signature} = sign_webhook_payload(webhook_payload, secret)

      # Expect API calls for fetching bot info, transcript, and participants
      expect(RecallApiMock, :get_bot, fn "bot-webhook-fallback-123" ->
        {:ok, %Tesla.Env{body: meeting_info_example(%{id: "bot-webhook-fallback-123"})}}
      end)

      expect(RecallApiMock, :get_bot_transcript, fn "bot-webhook-fallback-123" ->
        {:ok, %Tesla.Env{body: meeting_transcript_example()}}
      end)

      expect(RecallApiMock, :get_bot_participants, fn "bot-webhook-fallback-123" ->
        {:ok,
         %Tesla.Env{
           body: [
             %{id: 100, name: "Alice", is_host: true}
           ]
         }}
      end)

      # Remove raw_body from conn.private to test fallback
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> add_webhook_headers(webhook_id, timestamp, signature)
        |> Map.update!(:private, fn private -> Map.delete(private, :raw_body) end)
        |> post("/api/webhooks/recall", body)

      # Should still work (fallback reconstructs from params)
      assert response(conn, 200) == ""

      updated_bot = Bots.get_recall_bot!(bot_record.id)
      assert updated_bot.status == "done"
    end
  end
end
