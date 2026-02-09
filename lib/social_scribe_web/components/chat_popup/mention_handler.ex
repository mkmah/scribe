defmodule SocialScribeWeb.ChatPopup.MentionHandler do
  @moduledoc """
  Helper module for handling @mention functionality in ChatPopup.
  Provides functions for managing mention-related state and events.
  """

  alias SocialScribe.Accounts.User
  alias SocialScribe.Meetings.MeetingParticipant
  alias Phoenix.LiveView.Socket

  @doc """
  Loads deduplicated participants from all user meetings for mention autocomplete.
  """
  @spec load_user_participants(User.t()) :: list(MeetingParticipant.t())
  def load_user_participants(user) do
    alias SocialScribe.Meetings

    user
    |> Meetings.list_user_meetings()
    |> Enum.flat_map(& &1.meeting_participants)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Handles showing the mention menu when @ is typed.
  """
  @spec show_mention_menu(Socket.t(), String.t()) :: Socket.t()
  def show_mention_menu(socket, filter) do
    socket
    |> update_assign(:show_mention_menu, true)
    |> update_assign(:mention_filter, filter)
  end

  @doc """
  Handles hiding the mention menu.
  """
  @spec hide_mention_menu(Socket.t()) :: Socket.t()
  def hide_mention_menu(socket) do
    socket
    |> update_assign(:show_mention_menu, false)
    |> update_assign(:mention_filter, "")
  end

  @doc """
  Handles selecting a mention from the autocomplete menu.
  """
  @spec select_mention(Socket.t(), String.t()) :: Socket.t()
  def select_mention(socket, name) do
    socket
    |> update_assign(:show_mention_menu, false)
    |> update_assign(:mention_filter, "")
    |> push_event_to_socket("insert_mention", %{name: name})
  end

  @doc """
  Handles toggling the context menu (participant list).
  """
  @spec toggle_context_menu(Socket.t()) :: Socket.t()
  def toggle_context_menu(socket) do
    update_assign(socket, :show_context_menu, !socket.assigns.show_context_menu)
  end

  @doc """
  Handles closing the context menu.
  """
  @spec close_context_menu(Socket.t()) :: Socket.t()
  def close_context_menu(socket) do
    update_assign(socket, :show_context_menu, false)
  end

  @doc """
  Handles adding a participant to the message via context menu.
  """
  @spec add_participant_context(Socket.t(), String.t()) :: Socket.t()
  def add_participant_context(socket, name) do
    socket
    |> update_assign(:show_context_menu, false)
    |> push_event_to_socket("insert_mention", %{name: name})
  end

  # Helper to update socket assigns (assign is a macro, so we manipulate socket directly)
  defp update_assign(socket, key, value) do
    %{socket | assigns: Map.put(socket.assigns, key, value)}
  end

  # Helper to push events to socket (push_event is a macro, so we manipulate socket directly)
  defp push_event_to_socket(socket, event, payload) do
    # Phoenix LiveView stores pending events in socket.private.live_view_pending
    pending = Map.get(socket.private, :live_view_pending, [])
    new_pending = [{:push_event, event, payload} | pending]

    %{socket | private: Map.put(socket.private, :live_view_pending, new_pending)}
  end
end
