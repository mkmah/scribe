defmodule SocialScribe.ErrorHandler do
  @moduledoc """
  Common error handling utilities for consistent error formatting across the application.
  """

  require Logger

  @type error_reason :: atom() | String.t() | tuple()

  @doc """
  Formats an error tuple into a user-friendly message.

  ## Examples

      iex> format_error({:error, :not_found})
      "Resource not found"

      iex> format_error({:error, {:api_error, 404, "Not Found"}})
      "API error: Not Found (404)"

      iex> format_error({:error, "Custom error message"})
      "Custom error message"
  """
  @spec format_error({:error, error_reason()}) :: String.t()
  def format_error({:error, reason}) when is_atom(reason) do
    case reason do
      :not_found -> "Resource not found"
      :unauthorized -> "Unauthorized access"
      :forbidden -> "Access forbidden"
      :bad_request -> "Invalid request"
      :timeout -> "Request timed out"
      :network_error -> "Network error occurred"
      :token_refresh_failed -> "Failed to refresh authentication token"
      :no_participants -> "No participants found"
      :no_transcript -> "No transcript available"
      :unknown_provider -> "Unknown provider"
      _ -> "An error occurred: #{inspect(reason)}"
    end
  end

  def format_error({:error, {:api_error, status, body}}) when is_map(body) do
    message = Map.get(body, "message") || Map.get(body, "error") || "Unknown API error"
    "API error: #{message} (#{status})"
  end

  def format_error({:error, {:api_error, status, message}}) when is_binary(message) do
    "API error: #{message} (#{status})"
  end

  def format_error({:error, {:http_error, reason}}) do
    "HTTP error: #{inspect(reason)}"
  end

  def format_error({:error, {:token_refresh_failed, reason}}) do
    "Failed to refresh token: #{format_error({:error, reason})}"
  end

  def format_error({:error, reason}) when is_binary(reason) do
    reason
  end

  def format_error({:error, reason}) do
    "Error: #{inspect(reason)}"
  end

  @doc """
  Logs an error and returns a formatted error tuple.

  Useful for consistent error logging across the application.
  """
  @spec log_and_format_error(atom(), error_reason(), String.t()) :: {:error, String.t()}
  def log_and_format_error(level, reason, context \\ "") do
    message = format_error({:error, reason})
    full_message = if context != "", do: "#{context}: #{message}", else: message

    case level do
      :error -> Logger.error(full_message)
      :warning -> Logger.warning(full_message)
      :info -> Logger.info(full_message)
      _ -> Logger.debug(full_message)
    end

    {:error, message}
  end

  @doc """
  Wraps a function call with error handling and logging.

  Returns the result of the function call, or logs and returns an error tuple on failure.
  """
  @spec with_error_handling((-> result), String.t()) :: result | {:error, String.t()}
        when result: any()
  def with_error_handling(fun, context \\ "") when is_function(fun, 0) do
    try do
      fun.()
    rescue
      e ->
        log_and_format_error(:error, e, context)
    catch
      :exit, reason ->
        log_and_format_error(:error, reason, context)

      :throw, reason ->
        log_and_format_error(:error, reason, context)
    end
  end
end
