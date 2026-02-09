defmodule SocialScribeWeb.MeetingLive.Index do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo

  alias SocialScribe.Meetings

  @impl true
  def mount(_params, _session, socket) do
    meetings = Meetings.list_user_meetings(socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, "Past Meetings")
      |> assign(:meetings, meetings)

    {:ok, socket}
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    "#{minutes} min"
  end

  @impl true
  def handle_info({:chat_response, conversation_id, result}, socket) do
    # Forward chat response to ChatPopup component
    send_update(SocialScribeWeb.ChatPopup,
      id: "chat-popup",
      chat_response: {conversation_id, result}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_error, conversation_id, error}, socket) do
    # Forward chat error to ChatPopup component
    send_update(SocialScribeWeb.ChatPopup, id: "chat-popup", chat_error: {conversation_id, error})
    {:noreply, socket}
  end
end
