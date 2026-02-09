defmodule SocialScribeWeb.Components.ChatPopup.MentionHandlerTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribeWeb.ChatPopup.MentionHandler
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.CalendarFixtures

  describe "load_user_participants/1" do
    test "returns empty list when user has no meetings" do
      user = user_fixture()

      participants = MentionHandler.load_user_participants(user)

      assert participants == []
    end

    test "returns participants from user meetings" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      meeting = meeting_fixture(%{calendar_event_id: calendar_event.id})

      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Alice Smith"})
      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Bob Jones"})

      participants = MentionHandler.load_user_participants(user)

      assert length(participants) == 2
      names = Enum.map(participants, & &1.name)
      assert "Alice Smith" in names
      assert "Bob Jones" in names
    end

    test "deduplicates participants by name" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      meeting1 = meeting_fixture(%{calendar_event_id: calendar_event.id})
      meeting2 = meeting_fixture(%{calendar_event_id: calendar_event.id})

      # Same name in different meetings
      meeting_participant_fixture(%{meeting_id: meeting1.id, name: "Alice Smith"})
      meeting_participant_fixture(%{meeting_id: meeting2.id, name: "Alice Smith"})
      meeting_participant_fixture(%{meeting_id: meeting1.id, name: "Bob Jones"})

      participants = MentionHandler.load_user_participants(user)

      assert length(participants) == 2
      names = Enum.map(participants, & &1.name)
      assert "Alice Smith" in names
      assert "Bob Jones" in names
    end

    test "sorts participants by name" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      meeting = meeting_fixture(%{calendar_event_id: calendar_event.id})

      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Zoe Williams"})
      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Alice Smith"})
      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Bob Jones"})

      participants = MentionHandler.load_user_participants(user)

      assert length(participants) == 3
      names = Enum.map(participants, & &1.name)
      assert names == ["Alice Smith", "Bob Jones", "Zoe Williams"]
    end

    test "handles meetings with no participants" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      meeting_fixture(%{calendar_event_id: calendar_event.id})

      participants = MentionHandler.load_user_participants(user)

      assert participants == []
    end

    test "loads participants from multiple meetings" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      meeting1 = meeting_fixture(%{calendar_event_id: calendar_event.id})
      meeting2 = meeting_fixture(%{calendar_event_id: calendar_event.id})

      meeting_participant_fixture(%{meeting_id: meeting1.id, name: "Alice"})
      meeting_participant_fixture(%{meeting_id: meeting2.id, name: "Bob"})

      participants = MentionHandler.load_user_participants(user)

      assert length(participants) == 2
      names = Enum.map(participants, & &1.name)
      assert "Alice" in names
      assert "Bob" in names
    end
  end

  describe "show_mention_menu/2" do
    test "sets show_mention_menu to true" do
      socket = build_socket()

      result = MentionHandler.show_mention_menu(socket, "al")

      assert result.assigns.show_mention_menu == true
    end

    test "sets mention_filter to provided filter" do
      socket = build_socket()

      result = MentionHandler.show_mention_menu(socket, "alice")

      assert result.assigns.mention_filter == "alice"
    end

    test "handles empty filter string" do
      socket = build_socket()

      result = MentionHandler.show_mention_menu(socket, "")

      assert result.assigns.show_mention_menu == true
      assert result.assigns.mention_filter == ""
    end

    test "preserves other socket assigns" do
      socket = build_socket(%{other_key: "value"})

      result = MentionHandler.show_mention_menu(socket, "test")

      assert result.assigns.other_key == "value"
      assert result.assigns.show_mention_menu == true
    end
  end

  describe "hide_mention_menu/1" do
    test "sets show_mention_menu to false" do
      socket = build_socket(%{show_mention_menu: true})

      result = MentionHandler.hide_mention_menu(socket)

      assert result.assigns.show_mention_menu == false
    end

    test "sets mention_filter to empty string" do
      socket = build_socket(%{mention_filter: "alice"})

      result = MentionHandler.hide_mention_menu(socket)

      assert result.assigns.mention_filter == ""
    end

    test "works when menu is already hidden" do
      socket = build_socket(%{show_mention_menu: false})

      result = MentionHandler.hide_mention_menu(socket)

      assert result.assigns.show_mention_menu == false
    end

    test "preserves other socket assigns" do
      socket = build_socket(%{other_key: "value"})

      result = MentionHandler.hide_mention_menu(socket)

      assert result.assigns.other_key == "value"
    end
  end

  describe "select_mention/2" do
    test "sets show_mention_menu to false" do
      socket = build_socket(%{show_mention_menu: true})

      result = MentionHandler.select_mention(socket, "Alice Smith")

      assert result.assigns.show_mention_menu == false
    end

    test "sets mention_filter to empty string" do
      socket = build_socket(%{mention_filter: "alice"})

      result = MentionHandler.select_mention(socket, "Alice Smith")

      assert result.assigns.mention_filter == ""
    end

    test "pushes insert_mention event with name" do
      socket = build_socket()

      result = MentionHandler.select_mention(socket, "Alice Smith")

      pending = result.private[:live_view_pending]
      assert [{:push_event, "insert_mention", %{name: "Alice Smith"}}] = pending
    end

    test "preserves existing pending events" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{},
        private: %{live_view_pending: [{:push_event, "other_event", %{}}]}
      }

      result = MentionHandler.select_mention(socket, "Alice Smith")

      pending = result.private[:live_view_pending]
      assert length(pending) == 2
      assert {:push_event, "insert_mention", %{name: "Alice Smith"}} in pending
      assert {:push_event, "other_event", %{}} in pending
    end

    test "handles name with spaces" do
      socket = build_socket()

      result = MentionHandler.select_mention(socket, "Mary Jane Watson")

      pending = result.private[:live_view_pending]
      assert [{:push_event, "insert_mention", %{name: "Mary Jane Watson"}}] = pending
    end
  end

  describe "toggle_context_menu/1" do
    test "sets show_context_menu to true when false" do
      socket = build_socket(%{show_context_menu: false})

      result = MentionHandler.toggle_context_menu(socket)

      assert result.assigns.show_context_menu == true
    end

    test "sets show_context_menu to false when true" do
      socket = build_socket(%{show_context_menu: true})

      result = MentionHandler.toggle_context_menu(socket)

      assert result.assigns.show_context_menu == false
    end

    test "handles missing show_context_menu key" do
      socket = build_socket()

      # When key doesn't exist, accessing it raises KeyError
      # So we need to set it explicitly or handle the error
      assert_raise KeyError, fn ->
        MentionHandler.toggle_context_menu(socket)
      end
    end

    test "preserves other socket assigns" do
      socket = build_socket(%{show_context_menu: false, other_key: "value"})

      result = MentionHandler.toggle_context_menu(socket)

      assert result.assigns.other_key == "value"
      assert result.assigns.show_context_menu == true
    end
  end

  describe "close_context_menu/1" do
    test "sets show_context_menu to false" do
      socket = build_socket(%{show_context_menu: true})

      result = MentionHandler.close_context_menu(socket)

      assert result.assigns.show_context_menu == false
    end

    test "works when menu is already closed" do
      socket = build_socket(%{show_context_menu: false})

      result = MentionHandler.close_context_menu(socket)

      assert result.assigns.show_context_menu == false
    end

    test "preserves other socket assigns" do
      socket = build_socket(%{other_key: "value"})

      result = MentionHandler.close_context_menu(socket)

      assert result.assigns.other_key == "value"
    end
  end

  describe "add_participant_context/2" do
    test "sets show_context_menu to false" do
      socket = build_socket(%{show_context_menu: true})

      result = MentionHandler.add_participant_context(socket, "Alice Smith")

      assert result.assigns.show_context_menu == false
    end

    test "pushes insert_mention event with name" do
      socket = build_socket()

      result = MentionHandler.add_participant_context(socket, "Alice Smith")

      pending = result.private[:live_view_pending]
      assert [{:push_event, "insert_mention", %{name: "Alice Smith"}}] = pending
    end

    test "preserves existing pending events" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{},
        private: %{live_view_pending: [{:push_event, "other_event", %{}}]}
      }

      result = MentionHandler.add_participant_context(socket, "Bob Jones")

      pending = result.private[:live_view_pending]
      assert length(pending) == 2
      assert {:push_event, "insert_mention", %{name: "Bob Jones"}} in pending
      assert {:push_event, "other_event", %{}} in pending
    end

    test "handles name with spaces" do
      socket = build_socket()

      result = MentionHandler.add_participant_context(socket, "Mary Jane Watson")

      pending = result.private[:live_view_pending]
      assert [{:push_event, "insert_mention", %{name: "Mary Jane Watson"}}] = pending
    end

    test "preserves other socket assigns" do
      socket = build_socket(%{other_key: "value"})

      result = MentionHandler.add_participant_context(socket, "Alice")

      assert result.assigns.other_key == "value"
    end
  end

  # Helper function to build a minimal socket for testing
  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{}, assigns),
      private: %{}
    }
  end
end
