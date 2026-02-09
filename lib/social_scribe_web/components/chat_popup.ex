defmodule SocialScribeWeb.ChatPopup do
  @moduledoc """
  Floating chat popup LiveComponent that provides an "Ask Anything" chatbot
  accessible from any dashboard page.
  """
  use SocialScribeWeb, :live_component

  alias SocialScribe.Crm.Chat
  alias SocialScribeWeb.ChatPopup.MentionHandler
  alias SocialScribeWeb.ChatPopup.MessageList

  def handle_info({:chat_response, conversation_id, result}, socket) do
    require Logger
    Logger.debug("ChatPopup: Received chat_response for conversation #{conversation_id}")

    # Handle async chat response
    # Only process if this is still the current conversation
    current_conv_id =
      socket.assigns.current_conversation && socket.assigns.current_conversation.id

    if current_conv_id == conversation_id do
      Logger.debug("ChatPopup: Processing chat_response - conversation matches")

      case result do
        {:ok, %{user_message: _user_msg, assistant_message: _assistant_msg}} ->
          messages = Chat.get_conversation_messages(conversation_id)
          conversations = Chat.list_conversations(socket.assigns.current_user.id)

          socket =
            socket
            |> assign(:messages, messages)
            |> assign(:conversations, conversations)
            |> assign(:loading, false)

          Logger.debug("ChatPopup: Updated messages, loading set to false")
          {:noreply, socket}

        {:error, reason} ->
          Logger.error("ChatPopup: Error in chat_response: #{inspect(reason)}")
          socket = assign(socket, :loading, false)
          {:noreply, socket}
      end
    else
      Logger.debug(
        "ChatPopup: Conversation mismatch - current: #{inspect(current_conv_id)}, response: #{conversation_id}"
      )

      {:noreply, socket}
    end
  end

  def handle_info({:chat_error, _conversation_id, _error}, socket) do
    require Logger
    Logger.error("ChatPopup: Chat error occurred")
    socket = assign(socket, :loading, false)
    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Handle chat response from parent LiveView via send_update
    socket =
      if Map.has_key?(assigns, :chat_response) do
        {conversation_id, result} = assigns.chat_response
        handle_chat_response(conversation_id, result, socket)
      else
        socket
      end

    # Handle chat error from parent LiveView via send_update
    socket =
      if Map.has_key?(assigns, :chat_error) do
        {conversation_id, error} = assigns.chat_error
        handle_chat_error(conversation_id, error, socket)
      else
        socket
      end

    socket =
      socket
      |> assign_new(:open, fn -> false end)
      |> assign_new(:active_tab, fn -> :chat end)
      |> assign_new(:conversations, fn -> [] end)
      |> assign_new(:current_conversation, fn -> nil end)
      |> assign_new(:messages, fn -> [] end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:participants, fn -> [] end)
      |> assign_new(:show_context_menu, fn -> false end)
      |> assign_new(:show_mention_menu, fn -> false end)
      |> assign_new(:mention_filter, fn -> "" end)
      |> assign_new(:mentions, fn -> [] end)

    {:ok, socket}
  end

  # Handle chat response from async task (via send_update)
  defp handle_chat_response(conversation_id, result, socket) do
    current_conv_id =
      socket.assigns.current_conversation && socket.assigns.current_conversation.id

    if current_conv_id == conversation_id do
      case result do
        {:ok, %{user_message: _user_msg, assistant_message: _assistant_msg}} ->
          messages = Chat.get_conversation_messages(conversation_id)
          conversations = Chat.list_conversations(socket.assigns.current_user.id)

          socket
          |> assign(:messages, messages)
          |> assign(:conversations, conversations)
          |> assign(:loading, false)

        {:error, _reason} ->
          assign(socket, :loading, false)
      end
    else
      socket
    end
  end

  # Handle chat error from async task (via send_update)
  defp handle_chat_error(_conversation_id, _error, socket) do
    assign(socket, :loading, false)
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    open = !socket.assigns.open

    socket =
      if open do
        user = socket.assigns.current_user
        conversations = Chat.list_conversations(user.id)
        participants = MentionHandler.load_user_participants(user)
        assign(socket, open: true, conversations: conversations, participants: participants)
      else
        assign(socket, open: false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_chat", _params, socket) do
    {:noreply, assign(socket, open: false)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("new_chat", _params, socket) do
    socket =
      socket
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_conversation", %{"id" => id}, socket) do
    conversation = Chat.get_conversation!(id)
    messages = Chat.get_conversation_messages(conversation.id)

    socket =
      socket
      |> assign(:current_conversation, conversation)
      |> assign(:messages, messages)
      |> assign(:active_tab, :chat)

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.current_user
    message = String.trim(message)

    if message == "" do
      {:noreply, socket}
    else
      conversation =
        case socket.assigns.current_conversation do
          nil ->
            {:ok, conv} =
              Chat.create_conversation(%{
                user_id: user.id,
                title: String.slice(message, 0, 50)
              })

            conv

          conv ->
            conv
        end

      # Get current messages and add user message optimistically to UI
      current_messages = Chat.get_conversation_messages(conversation.id)

      # Create temporary user message for optimistic UI update
      optimistic_user_message = %{
        id: :temp,
        role: "user",
        content: message,
        inserted_at: DateTime.utc_now(),
        conversation_id: conversation.id
      }

      messages = current_messages ++ [optimistic_user_message]
      conversations = Chat.list_conversations(user.id)

      socket =
        socket
        |> assign(:current_conversation, conversation)
        |> assign(:messages, messages)
        |> assign(:conversations, conversations)
        |> assign(:loading, true)

      # Make AI call async (Chat.ask will create the actual user message in DB)
      ask_fn = Application.get_env(:social_scribe_web, :chat_ask_fn) || (&Chat.ask/3)

      # Spawn async task that sends message to LiveView process
      # The LiveView will forward it to this component via handle_info
      live_view_pid = self()
      require Logger

      Logger.debug(
        "ChatPopup: Starting async task for conversation #{conversation.id}, pid: #{inspect(live_view_pid)}"
      )

      Task.start(fn ->
        try do
          Logger.debug(
            "ChatPopup: Task started, calling ask_fn for conversation #{conversation.id}"
          )

          result = ask_fn.(conversation.id, message, user.id)

          Logger.debug(
            "ChatPopup: Task completed, result: #{inspect(result)}, sending message to #{inspect(live_view_pid)}"
          )

          # Send message to LiveView process, which will handle it
          send(live_view_pid, {:chat_response, conversation.id, result})
          Logger.debug("ChatPopup: Message sent successfully")
        rescue
          e ->
            Logger.error("ChatPopup: Failed to process chat: #{inspect(e)}")
            send(live_view_pid, {:chat_error, conversation.id, e})
        end
      end)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_context_menu", _params, socket) do
    {:noreply, MentionHandler.toggle_context_menu(socket)}
  end

  @impl true
  def handle_event("close_context_menu", _params, socket) do
    {:noreply, MentionHandler.close_context_menu(socket)}
  end

  @impl true
  def handle_event("add_participant_context", %{"name" => name}, socket) do
    {:noreply, MentionHandler.add_participant_context(socket, name)}
  end

  @impl true
  def handle_event("show_mention_menu", %{"filter" => filter}, socket) do
    {:noreply, MentionHandler.show_mention_menu(socket, filter)}
  end

  @impl true
  def handle_event("hide_mention_menu", _params, socket) do
    {:noreply, MentionHandler.hide_mention_menu(socket)}
  end

  @impl true
  def handle_event("select_mention", %{"name" => name}, socket) do
    {:noreply, MentionHandler.select_mention(socket, name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="chat-popup-wrapper">
      <%!-- Floating Action Button --%>
      <button
        phx-click="toggle_chat"
        phx-target={@myself}
        class={[
          "fixed bottom-6 right-6 z-50 flex items-center justify-center cursor-pointer",
          "w-14 h-14 rounded-full shadow-lg",
          "bg-primary text-primary-foreground hover:bg-primary/90",
          "transition-all duration-300 ease-out hover:scale-105 hover:shadow-lg",
          "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 ",
          @open && "rotate-0 scale-0 opacity-0 pointer-events-none"
        ]}
        aria-label="Open chat"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-6 h-6"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="1.5"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z"
          />
        </svg>
      </button>

      <%!-- Chat Panel --%>
      <div
        id="chat-panel"
        class={[
          "fixed bottom-6 right-6 z-50",
          "w-[460px] h-[680px] max-h-[85vh]",
          "bg-card rounded-2xl shadow-lg border border-border",
          "flex flex-col overflow-hidden",
          "transition-all duration-300 ease-out origin-bottom-right",
          if(@open,
            do: "scale-100 opacity-100 translate-y-0",
            else: "scale-95 opacity-0 translate-y-4 pointer-events-none"
          )
        ]}
      >
        <%!-- Panel Header --%>
        <div class="flex-shrink-0 px-5 pt-5 pb-3">
          <div class="flex items-center justify-between mb-3">
            <div class="flex items-center gap-2">
              <h2 class="text-lg font-semibold tracking-tight text-foreground">Ask Anything</h2>
            </div>
            <button
              phx-click="close_chat"
              phx-target={@myself}
              class="p-1.5 text-muted-foreground hover:text-secondary-foreground hover:bg-accent rounded-lg transition-colors cursor-pointer"
              title="Collapse"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="m5.25 4.5 7.5 7.5-7.5 7.5m6-15 7.5 7.5-7.5 7.5"
                />
              </svg>
            </button>
          </div>

          <%!-- Tabs --%>
          <div class="flex items-center gap-1">
            <button
              phx-click="switch_tab"
              phx-value-tab="chat"
              phx-target={@myself}
              class={[
                "text-sm font-medium px-3 py-1.5 rounded-md transition-colors cursor-pointer",
                if(@active_tab == :chat,
                  do: "text-foreground bg-muted",
                  else: "text-muted-foreground hover:text-foreground hover:bg-muted/50"
                )
              ]}
            >
              Chat
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="history"
              phx-target={@myself}
              class={[
                "text-sm font-medium px-3 py-1.5 rounded-md transition-colors cursor-pointer",
                if(@active_tab == :history,
                  do: "text-foreground bg-muted",
                  else: "text-muted-foreground hover:text-foreground hover:bg-muted/50"
                )
              ]}
            >
              History
            </button>
            <div class="flex-1"></div>
            <button
              phx-click="new_chat"
              phx-target={@myself}
              class="p-1 text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
              title="New chat"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
            </button>
          </div>
        </div>

        <%!-- Content: both panels kept in DOM so Chat input draft is preserved when switching tabs --%>
        <div class="flex flex-col flex-1 overflow-hidden">
          <div class={[
            "flex flex-col flex-1 overflow-hidden",
            @active_tab != :chat && "hidden"
          ]}>
            <MessageList.message_list
              messages={@messages}
              current_conversation={@current_conversation}
              loading={@loading}
            />

            <%!-- Input Area --%>
            <div class="flex-shrink-0 px-4 pt-2 pb-4 relative">
              <%!-- Context menu dropdown (from button click) - opens above so it's never cut off --%>
              <%= if @show_context_menu do %>
                <div
                  phx-click-away="close_context_menu"
                  phx-target={@myself}
                  class="absolute left-7 bottom-full mb-0.5 w-56 bg-card border border-border rounded-lg shadow-lg z-[100]"
                >
                  <div class="p-2 text-xs font-medium text-muted-foreground border-b border-border">
                    Meeting Participants
                  </div>
                  <div class="max-h-48 overflow-y-auto">
                    <%= if Enum.empty?(@participants) do %>
                      <div class="px-3 py-2 text-sm text-muted-foreground">
                        No participants found
                      </div>
                    <% else %>
                      <%= for participant <- @participants do %>
                        <button
                          type="button"
                          phx-click="add_participant_context"
                          phx-value-name={participant.name}
                          phx-target={@myself}
                          class="w-full text-left px-3 py-2 text-sm hover:bg-accent flex items-center gap-2 cursor-pointer"
                        >
                          <span class="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center text-xs font-medium text-primary">
                            {String.first(participant.name)}
                          </span>
                          <span class="truncate">{participant.name}</span>
                        </button>
                      <% end %>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <%!-- Mention autocomplete dropdown (from @ typing) - Client-side rendered --%>

              <form
                id="chat-popup-form"
                phx-submit="send_message"
                phx-target={@myself}
                data-participants={
                  Jason.encode!(Enum.map(@participants || [], fn p -> %{name: p.name} end))
                }
              >
                <div class="border-2 border-primary/40 rounded-xl overflow-hidden focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/20 transition-all bg-background">
                  <%!-- Add Context button (pill above input) --%>
                  <div class="px-3 pt-2.5">
                    <button
                      type="button"
                      phx-click="toggle_context_menu"
                      phx-target={@myself}
                      class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium text-muted-foreground hover:text-foreground bg-background border border-border rounded-md transition-colors cursor-pointer shadow-sm"
                    >
                      <span class="text-xs">@</span> Add context
                    </button>
                  </div>
                  <%!-- Textarea --%>
                  <div
                    id="chat-popup-textarea"
                    contenteditable="true"
                    role="textbox"
                    aria-multiline="true"
                    placeholder="Ask anything about your meetings"
                    data-placeholder="Ask anything about your meetings"
                    phx-hook="MentionInput"
                    phx-target={@myself}
                    class="mention-input min-h-[72px] max-h-32 overflow-y-auto w-full px-4 py-2 text-sm text-gray-900 placeholder:text-gray-400 bg-transparent border-0 resize-none dark:text-gray-100 dark:placeholder:text-gray-500 focus:ring-0 scrollbar-thin"
                    data-mentions={Enum.map_join(@mentions || [], ",", & &1.name)}
                  ></div>
                  <input
                    type="hidden"
                    name="message"
                    id="chat-popup-message-input"
                    phx-hook="MentionSync"
                  />
                  <%!-- Sources + Send at bottom --%>
                  <div class="flex items-center justify-between px-3 pb-2.5">
                    <MessageList.sources_badge />
                    <button
                      type="submit"
                      disabled={@loading}
                      class="flex items-center justify-center transition-all rounded-full cursor-pointer w-7 h-7 bg-primary/10 hover:bg-primary/20 text-primary disabled:opacity-40 disabled:cursor-not-allowed"
                      title="Send"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                        stroke-width="2.5"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M4.5 10.5L12 3m0 0l7.5 7.5M12 3v18"
                        />
                      </svg>
                    </button>
                  </div>
                </div>
              </form>
            </div>
          </div>
          <div class={[
            "flex-1 overflow-y-auto px-4 py-3 scrollbar-thin",
            @active_tab != :history && "hidden"
          ]}>
            <%= if Enum.empty?(@conversations) do %>
              <div class="py-12 text-center">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-10 h-10 mx-auto mb-3 text-gray-200 dark:text-gray-700"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="1"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155"
                  />
                </svg>
                <p class="text-sm font-medium text-muted-foreground">No conversations yet</p>
                <p class="mt-1 text-xs text-muted-foreground">Start a new chat to get started</p>
              </div>
            <% else %>
              <div class="space-y-2">
                <button
                  :for={conv <- @conversations}
                  phx-click="load_conversation"
                  phx-value-id={conv.id}
                  phx-target={@myself}
                  class="w-full text-left px-3 py-2.5 rounded-lg border border-border bg-card hover:bg-muted/50 hover:border-border/80 transition-all group cursor-pointer flex items-start gap-3"
                >
                  <div class="flex-shrink-0 w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center mt-0.5">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="w-4 h-4 text-primary"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="1.5"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"
                      />
                    </svg>
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-foreground truncate group-hover:text-foreground">
                      {conv.title}
                    </p>
                    <p class="text-xs text-muted-foreground/70 mt-0.5">
                      <.date_time datetime={conv.inserted_at} format="datetime" />
                    </p>
                  </div>
                  <div class="flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="w-4 h-4 text-muted-foreground"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M8.25 4.5l7.5 7.5-7.5 7.5"
                      />
                    </svg>
                  </div>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
