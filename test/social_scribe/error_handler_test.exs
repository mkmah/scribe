defmodule SocialScribe.ErrorHandlerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias SocialScribe.ErrorHandler

  describe "format_error/1" do
    test "formats :not_found atom" do
      assert ErrorHandler.format_error({:error, :not_found}) == "Resource not found"
    end

    test "formats :unauthorized atom" do
      assert ErrorHandler.format_error({:error, :unauthorized}) == "Unauthorized access"
    end

    test "formats :forbidden atom" do
      assert ErrorHandler.format_error({:error, :forbidden}) == "Access forbidden"
    end

    test "formats :bad_request atom" do
      assert ErrorHandler.format_error({:error, :bad_request}) == "Invalid request"
    end

    test "formats :timeout atom" do
      assert ErrorHandler.format_error({:error, :timeout}) == "Request timed out"
    end

    test "formats :network_error atom" do
      assert ErrorHandler.format_error({:error, :network_error}) == "Network error occurred"
    end

    test "formats :token_refresh_failed atom" do
      assert ErrorHandler.format_error({:error, :token_refresh_failed}) ==
               "Failed to refresh authentication token"
    end

    test "formats :no_participants atom" do
      assert ErrorHandler.format_error({:error, :no_participants}) == "No participants found"
    end

    test "formats :no_transcript atom" do
      assert ErrorHandler.format_error({:error, :no_transcript}) == "No transcript available"
    end

    test "formats :unknown_provider atom" do
      assert ErrorHandler.format_error({:error, :unknown_provider}) == "Unknown provider"
    end

    test "formats unknown atom with inspect" do
      assert ErrorHandler.format_error({:error, :unknown_atom}) ==
               "An error occurred: :unknown_atom"
    end

    test "formats api_error tuple with binary message" do
      assert ErrorHandler.format_error({:error, {:api_error, 404, "Not Found"}}) ==
               "API error: Not Found (404)"
    end

    test "formats api_error tuple with map body containing message key" do
      body = %{"message" => "Resource not found"}

      assert ErrorHandler.format_error({:error, {:api_error, 404, body}}) ==
               "API error: Resource not found (404)"
    end

    test "formats api_error tuple with map body containing error key" do
      body = %{"error" => "Unauthorized"}

      assert ErrorHandler.format_error({:error, {:api_error, 401, body}}) ==
               "API error: Unauthorized (401)"
    end

    test "formats api_error tuple with map body preferring message over error" do
      body = %{"message" => "Custom message", "error" => "Error text"}

      assert ErrorHandler.format_error({:error, {:api_error, 500, body}}) ==
               "API error: Custom message (500)"
    end

    test "formats api_error tuple with map body without message or error key" do
      body = %{"other" => "value"}

      assert ErrorHandler.format_error({:error, {:api_error, 500, body}}) ==
               "API error: Unknown API error (500)"
    end

    test "formats api_error tuple with empty map body" do
      assert ErrorHandler.format_error({:error, {:api_error, 500, %{}}}) ==
               "API error: Unknown API error (500)"
    end

    test "formats http_error tuple" do
      assert ErrorHandler.format_error({:error, {:http_error, :timeout}}) ==
               "HTTP error: :timeout"
    end

    test "formats http_error tuple with complex reason" do
      reason = {:econnrefused, "Connection refused"}

      assert ErrorHandler.format_error({:error, {:http_error, reason}}) ==
               "HTTP error: {:econnrefused, \"Connection refused\"}"
    end

    test "formats nested token_refresh_failed tuple" do
      assert ErrorHandler.format_error({:error, {:token_refresh_failed, :network_error}}) ==
               "Failed to refresh token: Network error occurred"
    end

    test "formats nested token_refresh_failed tuple with atom" do
      assert ErrorHandler.format_error({:error, {:token_refresh_failed, :not_found}}) ==
               "Failed to refresh token: Resource not found"
    end

    test "formats nested token_refresh_failed tuple with string" do
      assert ErrorHandler.format_error({:error, {:token_refresh_failed, "Custom error"}}) ==
               "Failed to refresh token: Custom error"
    end

    test "formats nested token_refresh_failed tuple with deeply nested error" do
      nested = {:api_error, 401, "Unauthorized"}

      assert ErrorHandler.format_error({:error, {:token_refresh_failed, nested}}) ==
               "Failed to refresh token: API error: Unauthorized (401)"
    end

    test "formats string error as-is" do
      assert ErrorHandler.format_error({:error, "Custom error message"}) ==
               "Custom error message"
    end

    test "formats empty string error" do
      assert ErrorHandler.format_error({:error, ""}) == ""
    end

    test "formats fallback error with tuple" do
      assert ErrorHandler.format_error({:error, {:custom, "error"}}) ==
               "Error: {:custom, \"error\"}"
    end

    test "formats fallback error with list" do
      assert ErrorHandler.format_error({:error, ["error1", "error2"]}) ==
               "Error: [\"error1\", \"error2\"]"
    end

    test "formats fallback error with number" do
      assert ErrorHandler.format_error({:error, 500}) == "Error: 500"
    end
  end

  describe "log_and_format_error/3" do
    test "logs error level and returns formatted error tuple" do
      log =
        capture_log(fn ->
          assert ErrorHandler.log_and_format_error(:error, :not_found) ==
                   {:error, "Resource not found"}
        end)

      assert log =~ "Resource not found"
    end

    test "logs warning level" do
      log =
        capture_log(fn ->
          assert ErrorHandler.log_and_format_error(:warning, :timeout) ==
                   {:error, "Request timed out"}
        end)

      assert log =~ "Request timed out"
    end

    test "logs info level" do
      original_level = Logger.level()

      try do
        Logger.configure(level: :info)

        log =
          capture_log(fn ->
            assert ErrorHandler.log_and_format_error(:info, :network_error) ==
                     {:error, "Network error occurred"}
          end)

        assert log =~ "Network error occurred"
      after
        Logger.configure(level: original_level)
      end
    end

    test "logs debug level for unknown level" do
      original_level = Logger.level()

      try do
        Logger.configure(level: :debug)

        log =
          capture_log(fn ->
            assert ErrorHandler.log_and_format_error(:debug, :bad_request) ==
                     {:error, "Invalid request"}
          end)

        assert log =~ "Invalid request"
      after
        Logger.configure(level: original_level)
      end
    end

    test "logs with context prefix when context is provided" do
      log =
        capture_log(fn ->
          assert ErrorHandler.log_and_format_error(:error, :not_found, "CRM API") ==
                   {:error, "Resource not found"}
        end)

      assert log =~ "CRM API: Resource not found"
    end

    test "logs without context prefix when context is empty" do
      log =
        capture_log(fn ->
          assert ErrorHandler.log_and_format_error(:error, :not_found, "") ==
                   {:error, "Resource not found"}
        end)

      assert log =~ "Resource not found"
      refute log =~ ": Resource not found"
    end

    test "returns error tuple without context prefix in message" do
      result = ErrorHandler.log_and_format_error(:error, :timeout, "Test Context")
      assert result == {:error, "Request timed out"}
      assert elem(result, 1) == "Request timed out"
    end

    test "formats complex error and logs with context" do
      log =
        capture_log(fn ->
          error = {:api_error, 500, "Internal Server Error"}

          assert ErrorHandler.log_and_format_error(:error, error, "API Call") ==
                   {:error, "API error: Internal Server Error (500)"}
        end)

      assert log =~ "API Call: API error: Internal Server Error (500)"
    end

    test "handles nested token refresh error with context" do
      log =
        capture_log(fn ->
          error = {:token_refresh_failed, :network_error}

          assert ErrorHandler.log_and_format_error(:warning, error, "OAuth") ==
                   {:error, "Failed to refresh token: Network error occurred"}
        end)

      assert log =~ "OAuth: Failed to refresh token: Network error occurred"
    end
  end

  describe "with_error_handling/2" do
    test "returns value when function succeeds" do
      result = ErrorHandler.with_error_handling(fn -> "success" end)
      assert result == "success"
    end

    test "returns tuple when function succeeds" do
      result = ErrorHandler.with_error_handling(fn -> {:ok, "data"} end)
      assert result == {:ok, "data"}
    end

    test "returns complex data structure when function succeeds" do
      data = %{key: "value", list: [1, 2, 3]}
      result = ErrorHandler.with_error_handling(fn -> data end)
      assert result == data
    end

    test "catches RuntimeError and returns error tuple" do
      log =
        capture_log(fn ->
          result =
            ErrorHandler.with_error_handling(fn ->
              raise RuntimeError, "Something went wrong"
            end)

          assert {:error, _message} = result
          assert is_binary(elem(result, 1))
        end)

      assert log =~ "Something went wrong" || log =~ "RuntimeError" || log =~ "Error:"
    end

    test "catches ArgumentError and returns error tuple" do
      log =
        capture_log(fn ->
          result =
            ErrorHandler.with_error_handling(fn ->
              raise ArgumentError, "Invalid argument"
            end)

          assert {:error, _message} = result
        end)

      assert log =~ "Invalid argument" || log =~ "ArgumentError" || log =~ "Error:"
    end

    test "catches custom exception and returns error tuple" do
      log =
        capture_log(fn ->
          result =
            ErrorHandler.with_error_handling(fn ->
              raise "Custom error"
            end)

          assert {:error, _message} = result
        end)

      assert log =~ "Custom error" || log =~ "RuntimeError" || log =~ "Error:"
    end

    test "catches exit signal and returns error tuple" do
      log =
        capture_log(fn ->
          result =
            ErrorHandler.with_error_handling(fn ->
              exit(:normal)
            end)

          assert {:error, _message} = result
        end)

      assert log =~ "An error occurred: :normal"
    end

    test "catches exit signal with reason and returns error tuple" do
      log =
        capture_log(fn ->
          result =
            ErrorHandler.with_error_handling(fn ->
              exit({:shutdown, "Process terminated"})
            end)

          assert {:error, _message} = result
        end)

      assert log =~ "shutdown" || log =~ "Process terminated"
    end

    test "catches throw and returns error tuple" do
      log =
        capture_log(fn ->
          result =
            ErrorHandler.with_error_handling(fn ->
              throw(:error_thrown)
            end)

          assert {:error, _message} = result
        end)

      assert log =~ "An error occurred: :error_thrown"
    end

    test "catches throw with value and returns error tuple" do
      log =
        capture_log(fn ->
          result =
            ErrorHandler.with_error_handling(fn ->
              throw({:error, "Something went wrong"})
            end)

          assert {:error, _message} = result
        end)

      assert log =~ "Something went wrong" || log =~ "error"
    end

    test "logs with context when provided" do
      log =
        capture_log(fn ->
          ErrorHandler.with_error_handling(
            fn ->
              raise RuntimeError, "Test error"
            end,
            "Test Context"
          )
        end)

      assert log =~ "Test Context:"
    end

    test "logs without context when empty" do
      log =
        capture_log(fn ->
          ErrorHandler.with_error_handling(
            fn ->
              raise RuntimeError, "Test error"
            end,
            ""
          )
        end)

      assert log =~ "Test error" || log =~ "RuntimeError" || log =~ "Error:"
      # Ensure context prefix is not present
      refute log =~ ": Test error"
    end

    test "handles function that returns error tuple" do
      result = ErrorHandler.with_error_handling(fn -> {:error, "Already an error"} end)
      assert result == {:error, "Already an error"}
    end

    test "handles function that returns nil" do
      result = ErrorHandler.with_error_handling(fn -> nil end)
      assert result == nil
    end

    test "handles function that returns false" do
      result = ErrorHandler.with_error_handling(fn -> false end)
      assert result == false
    end
  end
end
