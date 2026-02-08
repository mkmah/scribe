defmodule SocialScribe.GoogleCalendarTest do
  use ExUnit.Case, async: false

  alias SocialScribe.GoogleCalendar

  @start_time ~U[2025-01-01 00:00:00Z]
  @end_time ~U[2025-01-02 00:00:00Z]

  describe "list_events/4" do
    test "returns events on 200 response" do
      body = %{"items" => [%{"id" => "1", "summary" => "Meeting"}]}

      Tesla.Mock.mock(fn
        %{method: :get, url: _} ->
          %Tesla.Env{status: 200, body: body}
      end)

      assert {:ok, ^body} =
               GoogleCalendar.list_events("token", @start_time, @end_time, "primary")
    end

    test "returns error on non-200 response" do
      Tesla.Mock.mock(fn
        %{method: :get} ->
          %Tesla.Env{status: 401, body: %{"error" => "Unauthorized"}}
      end)

      assert {:error, {401, %{"error" => "Unauthorized"}}} =
               GoogleCalendar.list_events("token", @start_time, @end_time, "primary")
    end

    test "returns error on request failure" do
      Tesla.Mock.mock(fn
        %{method: :get} -> {:error, :timeout}
      end)

      assert {:error, :timeout} =
               GoogleCalendar.list_events("token", @start_time, @end_time, "primary")
    end
  end
end
