defmodule SocialScribeWeb.Components.UI.DateTimeTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule DateTimeTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:datetime, session["datetime"])
       |> Phoenix.LiveView.Utils.assign(:format, session["format"])
       |> Phoenix.LiveView.Utils.assign(:id, session["id"])}
    end

    def render(assigns) do
      ~H"""
      <.date_time datetime={@datetime} format={@format} id={@id} />
      """
    end
  end

  describe "UI.DateTime" do
    test "renders DateTime struct with default format", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => dt})

      assert html =~ "phx-hook=\"LocalDateTime\""
      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"datetime\""
      assert html =~ expected_iso
      assert html =~ "<span"
    end

    test "renders NaiveDateTime struct converted to UTC", %{conn: conn} do
      naive_dt = ~N[2026-02-09 15:30:00]
      dt = DateTime.from_naive!(naive_dt, "Etc/UTC")
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => naive_dt})

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ expected_iso
    end

    test "renders ISO8601 string directly", %{conn: conn} do
      iso_string = "2026-02-09T15:30:00Z"

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => iso_string})

      assert html =~ "data-datetime=\"#{iso_string}\""
      assert html =~ iso_string
    end

    test "renders nil datetime", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => nil})

      # When nil, data-datetime attribute is not rendered at all (Phoenix omits nil attributes)
      assert html =~ "phx-hook=\"LocalDateTime\""
      assert html =~ "data-format=\"datetime\""
      assert html =~ "<span"
      # Verify the span doesn't contain data-datetime attribute
      span_html = Regex.run(~r/<span[^>]*phx-hook="LocalDateTime"[^>]*>/, html)
      assert span_html != nil
      refute List.first(span_html) =~ "data-datetime"
    end

    test "handles invalid input by rendering nil", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => :invalid})

      # When invalid input, data-datetime attribute is not rendered at all (Phoenix omits nil attributes)
      assert html =~ "phx-hook=\"LocalDateTime\""
      assert html =~ "data-format=\"datetime\""
      assert html =~ "<span"
      # Verify the span doesn't contain data-datetime attribute
      span_html = Regex.run(~r/<span[^>]*phx-hook="LocalDateTime"[^>]*>/, html)
      assert span_html != nil
      refute List.first(span_html) =~ "data-datetime"
    end

    test "renders with date format", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => "date"}
        )

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"date\""
    end

    test "renders with time format", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => "time"}
        )

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"time\""
    end

    test "renders with relative format", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => "relative"}
        )

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"relative\""
    end

    test "renders with short format", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => "short"}
        )

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"short\""
    end

    test "renders with medium format", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => "medium"}
        )

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"medium\""
    end

    test "renders with long format", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => "long"}
        )

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"long\""
    end

    test "uses custom ID when provided", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      custom_id = "custom-datetime-id"

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "id" => custom_id}
        )

      assert html =~ "id=\"#{custom_id}\""
    end

    test "generates unique ID when not provided", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => dt})

      # Should match pattern "date-time-{number}"
      assert html =~ ~r/id="date-time-\d+"/
    end

    test "each instance gets unique auto-generated ID", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]

      defmodule MultipleDateTimeTestLive do
        use SocialScribeWeb, :live_view

        def mount(_params, session, socket) do
          {:ok,
           socket
           |> Phoenix.LiveView.Utils.assign(:datetime, session["datetime"])}
        end

        def render(assigns) do
          ~H"""
          <.date_time datetime={@datetime} />
          <.date_time datetime={@datetime} />
          <.date_time datetime={@datetime} />
          """
        end
      end

      {:ok, _view, html} =
        live_isolated(conn, MultipleDateTimeTestLive, session: %{"datetime" => dt})

      # Extract all IDs
      ids = Regex.scan(~r/id="(date-time-\d+)"/, html) |> Enum.map(&List.last/1)

      # Should have 3 unique IDs
      assert length(ids) == 3
      assert length(Enum.uniq(ids)) == 3
    end

    test "handles empty string as datetime", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => ""})

      # Empty string should be treated as binary and used directly
      assert html =~ "data-datetime=\"\""
    end

    test "handles non-ISO8601 string", %{conn: conn} do
      non_iso_string = "not an ISO8601 string"

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => non_iso_string})

      # String should be used directly even if not valid ISO8601
      assert html =~ "data-datetime=\"#{non_iso_string}\""
    end

    test "handles format attribute missing (uses default)", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      defmodule NoFormatTestLive do
        use SocialScribeWeb, :live_view

        def mount(_params, session, socket) do
          {:ok, socket |> Phoenix.LiveView.Utils.assign(:datetime, session["datetime"])}
        end

        def render(assigns) do
          ~H"""
          <.date_time datetime={@datetime} />
          """
        end
      end

      {:ok, _view, html} =
        live_isolated(conn, NoFormatTestLive, session: %{"datetime" => dt})

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"datetime\""
    end

    test "handles format explicitly set to nil (uses default)", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => nil}
        )

      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"datetime\""
    end

    test "renders with different timezone DateTime", %{conn: conn} do
      # Create DateTime in a different timezone
      dt = DateTime.from_naive!(~N[2026-02-09 15:30:00], "America/New_York")
      expected_iso = DateTime.to_iso8601(dt)

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive, session: %{"datetime" => dt})

      assert html =~ "data-datetime=\"#{expected_iso}\""
    end

    test "renders span element with correct attributes", %{conn: conn} do
      dt = ~U[2026-02-09 15:30:00Z]
      expected_iso = DateTime.to_iso8601(dt)
      custom_id = "test-id"

      {:ok, _view, html} =
        live_isolated(conn, DateTimeTestLive,
          session: %{"datetime" => dt, "format" => "date", "id" => custom_id}
        )

      # Verify all required attributes are present
      assert html =~ "<span"
      assert html =~ "id=\"#{custom_id}\""
      assert html =~ "phx-hook=\"LocalDateTime\""
      assert html =~ "data-datetime=\"#{expected_iso}\""
      assert html =~ "data-format=\"date\""
      # Verify ISO string is rendered as content (accounting for whitespace)
      assert html =~ expected_iso
      assert html =~ "</span>"
    end
  end
end
