defmodule SocialScribeWeb.RecallWebhookController do
  @moduledoc """
  Controller for handling webhook events from Recall.ai.

  Receives POST requests when bot status changes occur.
  Verifies webhook signatures using Svix signature verification.
  """

  use SocialScribeWeb, :controller

  alias SocialScribe.Bots
  alias SocialScribe.Bots.Processor

  require Logger

  @doc """
  Handles webhook POST requests from Recall.ai.

  Verifies the webhook signature before processing the payload.

  Expected payload structure (based on Recall.ai webhook format):
  ```json
  {
    "bot_id": "string",
    "event_type": "bot.done",
    "status": "done",
    "data": { ... }
  }
  ```
  """
  def handle(conn, params) do
    case verify_webhook_signature(conn) do
      :ok ->
        case parse_webhook_payload(params) do
          {:ok, bot_id, status, event_type} ->
            case Bots.get_recall_bot_by_recall_id(bot_id) do
              nil ->
                Logger.warning("Received webhook for unknown bot_id: #{bot_id}")
                send_resp(conn, 200, "")

              bot_record ->
                Logger.info(
                  "Received webhook for bot #{bot_id}: event_type=#{event_type}, status=#{status}"
                )

                Processor.handle_bot_status_change(bot_record, status)
                send_resp(conn, 200, "")
            end

          {:error, reason} ->
            Logger.error("Failed to parse webhook payload: #{inspect(reason)}")
            Logger.debug("Webhook payload: #{inspect(params)}")
            send_resp(conn, 400, "")
        end

      {:error, reason} ->
        Logger.warning("Webhook signature verification failed: #{inspect(reason)}")
        send_resp(conn, 401, "")
    end
  end

  defp verify_webhook_signature(conn) do
    webhook_secret = Application.get_env(:social_scribe, :recall_webhook_secret)

    # If webhook secret is not configured, skip verification (for development/testing)
    if is_nil(webhook_secret) or webhook_secret == "" do
      Logger.warning("RECALL_WEBHOOK_SECRET not configured, skipping signature verification")
      :ok
    else
      # Recall/Svix secrets are of the form "whsec_<base64-encoded-key>"
      # According to Svix docs, decode from regular base64 (not base64url)
      # For tests we also support plain secrets without the prefix.
      hmac_key =
        case webhook_secret do
          "whsec_" <> b64 ->
            # Try base64 first (standard Svix format)
            case Base.decode64(b64) do
              {:ok, key} ->
                key

              :error ->
                # Fallback to base64url (some implementations use this)
                case Base.url_decode64(b64, padding: false) do
                  {:ok, key} -> key
                  _ -> webhook_secret
                end
            end

          other ->
            other
        end

      with [webhook_id] <- get_req_header(conn, "webhook-id"),
           [timestamp] <- get_req_header(conn, "webhook-timestamp"),
           [signature_header] <- get_req_header(conn, "webhook-signature"),
           ["v1", signature_b64] <- String.split(signature_header, ",", parts: 2),
           raw_body <- get_raw_body(conn) do
        # Construct signed content: webhook_id + "." + timestamp + "." + raw_body
        signed_content = Enum.join([webhook_id, timestamp, raw_body], ".")

        # Compute expected signature using HMAC-SHA256
        expected_signature =
          :crypto.mac(:hmac, :sha256, hmac_key, signed_content)
          |> Base.encode64()

        # Debug logging (remove in production)
        Logger.debug("""
        Webhook signature verification:
        - Webhook ID: #{webhook_id}
        - Timestamp: #{timestamp}
        - Raw body length: #{byte_size(raw_body)}
        - Signed content length: #{byte_size(signed_content)}
        - Expected signature: #{expected_signature}
        - Received signature: #{signature_b64}
        - HMAC key length: #{byte_size(hmac_key)}
        """)

        # Use secure comparison to prevent timing attacks
        if Plug.Crypto.secure_compare(expected_signature, signature_b64) do
          :ok
        else
          {:error, :invalid_signature}
        end
      else
        [] ->
          {:error, :missing_headers}

        _ ->
          {:error, :invalid_signature_format}
      end
    end
  end

  defp get_raw_body(conn) do
    # Get raw body from conn.private (set by RawBodyReader plug)
    case Map.get(conn.private, :raw_body) do
      nil ->
        # Fallback: reconstruct JSON body from params
        # This should not happen if RawBodyReader plug is properly configured
        Logger.warning("Raw body not found in conn.private, reconstructing from params")
        Jason.encode!(conn.params)

      raw_body ->
        raw_body
    end
  end

  defp parse_webhook_payload(params) do
    # Recall.ai webhook format:
    # {
    #   "event": "bot.in_waiting_room",
    #   "data": {
    #     "bot": {"id": "...", "metadata": {}},
    #     "data": {"code": "in_waiting_room", "sub_code": null, "updated_at": "..."}
    #   }
    # }
    with event_type when is_binary(event_type) <-
           Map.get(params, "event") || Map.get(params, :event) || Map.get(params, "event_type"),
         data when is_map(data) <- Map.get(params, "data") || Map.get(params, :data),
         bot_data when is_map(bot_data) <- Map.get(data, "bot") || Map.get(data, :bot),
         bot_id when is_binary(bot_id) <- Map.get(bot_data, "id") || Map.get(bot_data, :id),
         status <- extract_status_from_event(event_type, data) do
      {:ok, bot_id, status, event_type}
    else
      nil ->
        {:error, :missing_bot_id}

      error ->
        {:error, {:invalid_payload, error}}
    end
  end

  defp extract_status_from_event(event_type, data) do
    # Try to get status from data.data.code first (Recall.ai format)
    case get_in(data, ["data", "code"]) || get_in(data, [:data, :code]) do
      nil ->
        # Fallback: extract status from event_type (e.g., "bot.done" -> "done")
        case String.split(event_type, ".") do
          ["bot", status] -> status
          _ -> event_type
        end

      status ->
        status
    end
  end
end
