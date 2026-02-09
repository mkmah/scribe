defmodule SocialScribeWeb.UI.DateTime do
  @moduledoc """
  Date and time formatting component that displays dates/times in the browser's local timezone.

  ## Examples

      <.date_time datetime={~U[2026-02-09 15:30:00Z]} />
      <.date_time datetime={~U[2026-02-09 15:30:00Z]} format="date" />
      <.date_time datetime={~U[2026-02-09 15:30:00Z]} format="time" />
      <.date_time datetime={~U[2026-02-09 15:30:00Z]} format="relative" />

  ## Formats

  - `datetime` (default) - Full date and time: "Feb 9, 2026, 3:30 PM"
  - `date` - Date only: "Feb 9, 2026"
  - `time` - Time only: "3:30 PM"
  - `relative` - Relative format: "Today at 3:30 PM", "Yesterday at 2:30 PM", "Feb 9 at 1:00 PM"
  - `short` - Short date: "02/09/2026"
  - `medium` - Medium date: "Feb 9, 2026"
  - `long` - Long date: "February 9, 2026"
  """
  use Phoenix.Component

  @doc """
  Renders a date/time that will be formatted client-side in the browser's local timezone.

  ## Attributes

  - `datetime` (required) - A `DateTime` struct or ISO8601 string
  - `format` - Format style: `datetime`, `date`, `time`, `relative`, `short`, `medium`, `long` (default: `datetime`)
  """
  attr :datetime, :any, required: true, doc: "DateTime struct or ISO8601 string"
  attr :format, :string, default: "datetime", doc: "Format style"
  attr :id, :string, doc: "Optional ID for the element"

  def date_time(assigns) do
    iso_string =
      case assigns.datetime do
        %DateTime{} = dt ->
          DateTime.to_iso8601(dt)

        %NaiveDateTime{} = dt ->
          # Convert NaiveDateTime to ISO8601 (assumes UTC)
          dt
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_iso8601()

        string when is_binary(string) ->
          # If it's already an ISO8601 string, use it directly
          string

        nil ->
          nil

        _ ->
          nil
      end

    format = assigns[:format] || "datetime"

    # Generate a unique ID if not provided
    id = assigns[:id] || "date-time-#{System.unique_integer([:positive, :monotonic])}"

    assigns =
      assigns
      |> assign(:iso_string, iso_string)
      |> assign(:format, format)
      |> assign(:id, id)

    ~H"""
    <span id={@id} phx-hook="LocalDateTime" data-datetime={@iso_string} data-format={@format}>
      {@iso_string}
    </span>
    """
  end
end
