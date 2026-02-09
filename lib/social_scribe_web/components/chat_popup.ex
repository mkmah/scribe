defmodule SocialScribeWeb.ChatPopup do
  @moduledoc """
  Floating chat popup LiveComponent that provides an "Ask Anything" chatbot
  accessible from any dashboard page.
  """
  use SocialScribeWeb, :live_component

  alias SocialScribe.Crm.Chat
  alias SocialScribe.Meetings

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
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

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    open = !socket.assigns.open

    socket =
      if open do
        user = socket.assigns.current_user
        conversations = Chat.list_conversations(user.id)
        participants = load_user_participants(user)
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

      socket =
        socket
        |> assign(:current_conversation, conversation)
        |> assign(:loading, true)

      ask_fn = Application.get_env(:social_scribe_web, :chat_ask_fn) || (&Chat.ask/3)

      case ask_fn.(conversation.id, message, user.id) do
        {:ok, %{user_message: _user_msg, assistant_message: _assistant_msg}} ->
          messages = Chat.get_conversation_messages(conversation.id)
          conversations = Chat.list_conversations(user.id)

          socket =
            socket
            |> assign(:messages, messages)
            |> assign(:conversations, conversations)
            |> assign(:loading, false)

          {:noreply, socket}

        {:error, _reason} ->
          socket =
            socket
            |> assign(:loading, false)

          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_context_menu", _params, socket) do
    {:noreply, assign(socket, :show_context_menu, !socket.assigns.show_context_menu)}
  end

  @impl true
  def handle_event("close_context_menu", _params, socket) do
    {:noreply, assign(socket, :show_context_menu, false)}
  end

  @impl true
  def handle_event("add_participant_context", %{"name" => name}, socket) do
    # Insert the @mention into the textarea via JS event
    socket =
      socket
      |> assign(:show_context_menu, false)
      |> push_event("insert_mention", %{name: name})

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_mention_menu", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, show_mention_menu: true, mention_filter: filter)}
  end

  @impl true
  def handle_event("hide_mention_menu", _params, socket) do
    {:noreply, assign(socket, show_mention_menu: false, mention_filter: "")}
  end

  @impl true
  def handle_event("select_mention", %{"name" => name}, socket) do
    socket =
      socket
      |> assign(show_mention_menu: false, mention_filter: "")
      |> push_event("insert_mention", %{name: name})

    {:noreply, socket}
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
            <h2 class="text-lg font-semibold tracking-tight text-foreground">Ask Anything</h2>
            <div class="flex items-center gap-1">
              <button
                phx-click="new_chat"
                phx-target={@myself}
                class="p-1.5 text-muted-foreground hover:text-secondary-foreground hover:bg-accent rounded-lg transition-colors cursor-pointer"
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
              <button
                phx-click="close_chat"
                phx-target={@myself}
                class="p-1.5 text-muted-foreground hover:text-secondary-foreground hover:bg-accent rounded-lg transition-colors cursor-pointer"
                title="Close"
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
                    d="m18.75 4.5-7.5 7.5 7.5 7.5m-6-15L5.25 12l7.5 7.5"
                  />
                </svg>
              </button>
            </div>
          </div>

          <%!-- Tabs --%>
          <div class="flex gap-1 border-b border-border">
            <button
              phx-click="switch_tab"
              phx-value-tab="chat"
              phx-target={@myself}
              class={[
                "text-sm font-medium px-3 py-2 rounded-t-lg transition-colors cursor-pointer",
                if(@active_tab == :chat,
                  do: "text-foreground bg-muted/80 border border-border border-b-0 -mb-px",
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
                "text-sm font-medium px-3 py-2 rounded-t-lg transition-colors cursor-pointer",
                if(@active_tab == :history,
                  do: "text-foreground bg-muted/80 border border-border border-b-0 -mb-px",
                  else: "text-muted-foreground hover:text-foreground hover:bg-muted/50"
                )
              ]}
            >
              History
            </button>
          </div>
        </div>

        <%!-- Content: both panels kept in DOM so Chat input draft is preserved when switching tabs --%>
        <div class="flex flex-col flex-1 overflow-hidden">
          <div class={[
            "flex flex-col flex-1 overflow-hidden",
            @active_tab != :chat && "hidden"
          ]}>
            <div
              id="chat-popup-messages"
              phx-hook="ScrollToBottom"
              class="flex-1 px-5 py-4 space-y-4 overflow-y-auto scrollbar-thin"
            >
              <%!-- Timestamp at top --%>
              <%= if @current_conversation do %>
                <div class="text-center text-xs text-muted-foreground pb-2 border-b border-border mb-2">
                  <.date_time datetime={@current_conversation.inserted_at} format="datetime" />
                </div>
              <% end %>

              <%= if Enum.empty?(@messages) do %>
                <div class="pt-4">
                  <p class="text-sm leading-relaxed text-muted-foreground">
                    I can answer questions about your meetings and data &ndash; just ask!
                  </p>
                </div>
              <% else %>
                <%= for message <- @messages do %>
                  <%= if message.role == "user" do %>
                    <div class="flex justify-end">
                      <div class="max-w-[85%] bg-muted rounded-2xl rounded-br-md px-4 py-2.5 border border-border/60 shadow-sm">
                        <p class="text-sm leading-relaxed text-foreground">
                          <.message_content_block content={message.content} />
                        </p>
                      </div>
                    </div>
                  <% else %>
                    <div class="flex justify-start">
                      <div class="max-w-[85%]">
                        <p class="text-sm leading-relaxed text-gray-700 dark:text-gray-300">
                          <.message_content_block content={message.content} />
                        </p>
                        <%!-- Sources below assistant replies --%>
                        <%= if message.metadata && message.metadata["sources"] && Enum.any?(message.metadata["sources"]) do %>
                          <div class="flex items-center gap-1.5 mt-2">
                            <span class="text-xs text-muted-foreground">Sources</span>
                            <div class="flex -space-x-1">
                              <%= for source <- message.metadata["sources"] do %>
                                <.source_icon source={source} />
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              <% end %>

              <div :if={@loading} class="flex justify-start">
                <div class="flex items-center gap-2">
                  <div class="flex gap-1">
                    <span class="w-1.5 h-1.5 bg-gray-400 dark:bg-gray-500 rounded-full animate-bounce [animation-delay:0ms]">
                    </span>
                    <span class="w-1.5 h-1.5 bg-gray-400 dark:bg-gray-500 rounded-full animate-bounce [animation-delay:150ms]">
                    </span>
                    <span class="w-1.5 h-1.5 bg-gray-400 dark:bg-gray-500 rounded-full animate-bounce [animation-delay:300ms]">
                    </span>
                  </div>
                  <span class="text-xs text-muted-foreground">Thinking...</span>
                </div>
              </div>
            </div>

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
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-muted-foreground hover:text-foreground bg-muted/80 hover:bg-muted border border-border rounded-full transition-colors cursor-pointer"
                    >
                      @ Add context
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
                    onkeydown="if(event.key==='Enter'&&!event.shiftKey){event.preventDefault();this.closest('form').requestSubmit()}"
                  ></div>
                  <input
                    type="hidden"
                    name="message"
                    id="chat-popup-message-input"
                    phx-hook="MentionSync"
                  />
                  <%!-- Sources + Send at bottom --%>
                  <div class="flex items-center justify-between px-3 pb-2.5">
                    <div class="flex items-center gap-2">
                      <span class="text-xs text-muted-foreground">Sources</span>
                      <div class="flex -space-x-1.5">
                        <div
                          class="w-5 h-5 rounded-full bg-[#00A1E0] flex items-center justify-center ring-2 ring-white dark:ring-card"
                          title="Salesforce"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                            class="w-3 h-3"
                            fill="white"
                          >
                            <path d="M17.05 2.55c-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52l-1.67 1.67c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52l-1.67 1.67c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.13.57.66.96 1.24.92.28-.02.54-.14.74-.33l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.04-.19-.13-.37-.26-.52l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.13-.57-.66-.96-1.24-.92-.28.02-.54.14-.74.33l-1.67 1.67c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52L6.78 10.6c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.13.57.66.96 1.24.92.28-.02.54-.14.74-.33l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.04-.19-.13-.37-.26-.52l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.13-.57-.66-.96-1.24-.92-.28.02-.54.14-.74.33L9.06 6.09c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52l1.67 1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.04-.19-.13-.37-.26-.52l1.67-1.67c-.14-.15-.22-.33-.26-.52-.13-.64.28-1.25.92-1.4.58-.04 1.11.35 1.24.92.04.19-.02.39-.13.57l-1.67 1.67c.14.15.22.33.26.52.13.64-.28 1.25-.92 1.4-.58.04-1.11-.35-1.24-.92-.04-.19.02-.39.13-.57L7.44 5.33c.14-.15.22-.33.26-.52.13-.64-.28-1.25-.92-1.4-.58-.04-1.11.35-1.24.92-.04.19.02.39.13.57l1.67 1.67c-.14.15-.22.33-.26.52-.13.64.28 1.25.92 1.4.58.04 1.11-.35 1.24-.92.04-.19-.02-.39-.13-.57l-1.67-1.67c.14-.15.22-.33.26-.52.13-.64-.28-1.25-.92-1.4-.58-.04-1.11.35-1.24.92-.04.19.02.39.13.57l1.67 1.67c-.14.15-.22.33-.26.52-.13.64.28 1.25.92 1.4.58.04 1.11-.35 1.24-.92.04-.19-.02-.39-.13-.57L5.22 3.98c.14-.15.22-.33.26-.52.13-.64-.28-1.25-.92-1.4-.58-.04-1.11.35-1.24.92-.04.19.02.39.13.57l1.67 1.67c-.14.15-.22.33-.26.52-.13.64.28 1.25.92 1.4.58.04 1.11-.35 1.24-.92.04-.19-.02-.39-.13-.57l-1.67-1.67z" />
                          </svg>
                        </div>
                        <div
                          class="w-5 h-5 rounded-full bg-[#FF7A59] flex items-center justify-center ring-2 ring-white dark:ring-card"
                          title="HubSpot"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                            class="w-3 h-3"
                            fill="white"
                          >
                            <path d="M18.164 7.93V3.836a1.5 1.5 0 0 0-3 0v7.5h-1.5V2.336a1.5 1.5 0 0 0-3 0v9h-1.5v-7.5a1.5 1.5 0 0 0-3 0v9c0 3.244 2.175 5.977 5.143 6.807L10.664 22.5a1.5 1.5 0 0 0 3 0v-1.5c3.728 0 6.75-3.022 6.75-6.75V7.93h-2.25z" />
                          </svg>
                        </div>
                        <div
                          class="w-5 h-5 rounded-full bg-[#EA4335] flex items-center justify-center ring-2 ring-white dark:ring-card"
                          title="Gmail"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                            class="w-3 h-3"
                            fill="white"
                          >
                            <path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" />
                          </svg>
                        </div>
                      </div>
                    </div>
                    <button
                      type="submit"
                      disabled={@loading}
                      class="flex items-center justify-center transition-all rounded-lg cursor-pointer w-8 h-8 bg-muted hover:bg-muted/80 text-foreground border border-border disabled:opacity-40 disabled:cursor-not-allowed"
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
            "flex-1 overflow-y-auto px-5 py-4 space-y-1.5 scrollbar-thin",
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
              <button
                :for={conv <- @conversations}
                phx-click="load_conversation"
                phx-value-id={conv.id}
                phx-target={@myself}
                class="w-full text-left px-3.5 py-3 rounded-xl hover:bg-gray-50 dark:hover:bg-[#2a2a2a] transition-colors group cursor-pointer"
              >
                <p class="text-sm font-medium text-gray-800 truncate dark:text-gray-200 group-hover:text-gray-900 dark:group-hover:text-gray-100">
                  {conv.title}
                </p>
                <p class="text-xs text-muted-foreground mt-0.5">
                  <.date_time datetime={conv.inserted_at} format="datetime" />
                </p>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Split message content into text and @mention segments for pill rendering
  defp message_content_segments(content) when is_binary(content) do
    Regex.split(~r/(@[A-Za-z][A-Za-z0-9]*(?:\s+[A-Za-z][A-Za-z0-9]*)*)/, content,
      include_captures: true
    )
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn
      <<"@", _::binary>> = segment -> {:mention, String.trim_leading(segment, "@")}
      segment -> {:text, segment}
    end)
  end

  defp message_content_segments(_), do: [{:text, ""}]

  defp message_content_block(assigns) do
    assigns = assign(assigns, :segments, message_content_segments(assigns.content))

    ~H"""
    <%= for segment <- @segments do %>
      <%= case segment do %>
        <% {:text, text} -> %>
          {text}
        <% {:mention, name} -> %>
          <span class="mention-pill-inline">
            <span class="mention-pill-inline-avatar">{String.first(name)}</span>
            <span class="mention-pill-inline-name">{name}</span>
          </span>
      <% end %>
    <% end %>
    """
  end

  # Load deduplicated participants from all user meetings
  # Note: We can't exclude the current user since User has email but MeetingParticipant only has name
  defp load_user_participants(user) do
    user
    |> Meetings.list_user_meetings()
    |> Enum.flat_map(& &1.meeting_participants)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.name)
  end

  # Source icon component for displaying data sources
  defp source_icon(assigns) do
    ~H"""
    <%= case @source do %>
      <% "salesforce" -> %>
        <div
          class="w-4 h-4 rounded-full bg-[#00A1E0] flex items-center justify-center ring-1 ring-white dark:ring-card"
          title="Salesforce"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-2.5 h-2.5" fill="white">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
          </svg>
        </div>
      <% "hubspot" -> %>
        <div
          class="w-4 h-4 rounded-full bg-[#FF7A59] flex items-center justify-center ring-1 ring-white dark:ring-card"
          title="HubSpot"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-2.5 h-2.5" fill="white">
            <circle cx="12" cy="12" r="6" />
          </svg>
        </div>
      <% "meeting" -> %>
        <div
          class="w-4 h-4 rounded-full bg-gray-600 flex items-center justify-center ring-1 ring-white dark:ring-card"
          title="Meeting"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-2.5 h-2.5" fill="white">
            <path d="M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z" />
          </svg>
        </div>
      <% _ -> %>
        <div
          class="w-4 h-4 rounded-full bg-gray-400 flex items-center justify-center ring-1 ring-white dark:ring-card"
          title={@source}
        >
          <span class="text-[6px] font-bold text-white uppercase">
            {String.first(@source || "?")}
          </span>
        </div>
    <% end %>
    """
  end
end
