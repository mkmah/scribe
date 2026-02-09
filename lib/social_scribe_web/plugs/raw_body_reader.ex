defmodule SocialScribeWeb.Plugs.RawBodyReader do
  @moduledoc """
  Custom body reader for Plug.Parsers that stores the raw request body.

  This is needed for webhook signature verification - we need the raw bytes
  to verify HMAC signatures, but Plug.Parsers normally consumes the body.

  This module provides both:
  1. A function for Plug.Parsers body_reader option
  2. A plug that can be used in routes (for backwards compatibility)
  """

  import Plug.Conn, except: [read_body: 2]

  @max_body_length 1_000_000

  @doc """
  Body reader function for Plug.Parsers.

  Reads the body and stores it in conn.private[:raw_body] for later use.
  Returns the body so Plug.Parsers can parse it normally.
  """
  def read_body(conn, opts) do
    max_length = Keyword.get(opts, :length, @max_body_length)

    case Plug.Conn.read_body(conn, length: max_length) do
      {:ok, body, conn} ->
        # Store raw body in conn.private for signature verification
        conn = put_in(conn.private[:raw_body], body)
        {:ok, body, conn}

      {:more, body, conn} ->
        # Body too large
        {:ok, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Plug implementation (for backwards compatibility or direct use).
  """
  def init(opts), do: opts

  def call(conn, _opts) do
    # If body already read by Plug.Parsers, this is a no-op
    if Map.has_key?(conn.private, :raw_body) do
      conn
    else
      case Plug.Conn.read_body(conn, length: @max_body_length) do
        {:ok, body, conn} ->
          put_in(conn.private[:raw_body], body)

        {:more, _body, conn} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(413, Jason.encode!(%{error: "Request body too large"}))
          |> halt()

        {:error, _reason} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(400, Jason.encode!(%{error: "Failed to read request body"}))
          |> halt()
      end
    end
  end
end
