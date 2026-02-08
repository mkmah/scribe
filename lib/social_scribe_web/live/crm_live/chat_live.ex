defmodule SocialScribeWeb.CrmLive.ChatLive do
  use SocialScribeWeb, :live_view

  alias SocialScribe.Crm.Chat

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    conversations = Chat.list_conversations(user.id)

    socket =
      socket
      |> assign(:page_title, "Ask Anything")
      |> assign(:conversations, conversations)
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])
      |> assign(:active_tab, :chat)
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.current_user
    message = String.trim(message)

    if message == "" do
      {:noreply, socket}
    else
      # Create conversation if needed
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

      # Show user message immediately
      socket =
        socket
        |> assign(:current_conversation, conversation)
        |> assign(:loading, true)

      # Process the ask flow
      case Chat.ask(conversation.id, message, user.id) do
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
            |> put_flash(:error, "Failed to process your question. Please try again.")
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
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
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
  def handle_event("new_chat", _params, socket) do
    socket =
      socket
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[calc(100vh-4rem)]">
      <%!-- Header --%>
      <div class="px-6 py-4 border-b border-slate-200">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <.icon name="hero-chat-bubble-left-right" class="w-6 h-6 text-indigo-600" />
            <h1 class="text-xl font-bold text-slate-900">Ask Anything</h1>
          </div>
          <button
            phx-click="new_chat"
            class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors"
          >
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Chat
          </button>
        </div>

        <%!-- Tabs --%>
        <div class="flex gap-6 mt-4">
          <button
            phx-click="switch_tab"
            phx-value-tab="chat"
            class={[
              "text-sm font-medium pb-2 border-b-2 transition-colors",
              if(@active_tab == :chat,
                do: "text-indigo-600 border-indigo-600",
                else: "text-slate-500 border-transparent hover:text-slate-700"
              )
            ]}
          >
            Chat
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="history"
            class={[
              "text-sm font-medium pb-2 border-b-2 transition-colors",
              if(@active_tab == :history,
                do: "text-indigo-600 border-indigo-600",
                else: "text-slate-500 border-transparent hover:text-slate-700"
              )
            ]}
          >
            History
          </button>
        </div>
      </div>

      <%!-- Content Area --%>
      <div class="flex-1 overflow-hidden">
        <%= if @active_tab == :chat do %>
          <div class="flex flex-col h-full">
            <%!-- Messages --%>
            <div class="flex-1 px-6 py-4 space-y-4 overflow-y-auto" id="chat-messages">
              <%= if Enum.empty?(@messages) do %>
                <div class="flex items-start gap-3 mt-8">
                  <div class="flex items-center justify-center flex-shrink-0 w-8 h-8 bg-indigo-100 rounded-full">
                    <.icon name="hero-sparkles" class="w-4 h-4 text-indigo-600" />
                  </div>
                  <div class="text-sm text-slate-700">
                    <p class="mb-1 font-medium text-slate-900">How can I help you today?</p>
                    <p>
                      Ask anything about your meetings or CRM contacts. Use
                      <span class="font-medium text-indigo-600">@Name</span>
                      to reference specific contacts.
                    </p>
                  </div>
                </div>
              <% else %>
                <%= for message <- @messages do %>
                  <div class={[
                    "flex",
                    if(message.role == "user", do: "justify-end", else: "justify-start")
                  ]}>
                    <div class={[
                      "max-w-[70%]",
                      if(message.role == "user",
                        do: "bg-gray-100 rounded-2xl px-4 py-3",
                        else: ""
                      )
                    ]}>
                      <%= if message.role == "assistant" do %>
                        <div class="flex items-start gap-3">
                          <div class="flex items-center justify-center flex-shrink-0 w-8 h-8 bg-indigo-100 rounded-full">
                            <.icon name="hero-sparkles" class="w-4 h-4 text-indigo-600" />
                          </div>
                          <div class="text-sm text-slate-700">
                            {format_message_content(message.content)}
                          </div>
                        </div>
                      <% else %>
                        <p class="text-sm text-slate-900">
                          {format_message_content(message.content)}
                        </p>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>

              <div :if={@loading} class="flex justify-start">
                <div class="flex items-start gap-3">
                  <div class="flex items-center justify-center flex-shrink-0 w-8 h-8 bg-indigo-100 rounded-full">
                    <.icon name="hero-sparkles" class="w-4 h-4 text-indigo-600 animate-pulse" />
                  </div>
                  <div class="text-sm text-slate-500">Thinking...</div>
                </div>
              </div>
            </div>

            <%!-- Input --%>
            <div class="px-6 py-4 border-t border-slate-200">
              <form id="chat-form" phx-submit="send_message" class="flex items-center gap-3">
                <div class="relative flex-1">
                  <input
                    type="text"
                    name="message"
                    placeholder="Ask anything about your meetings"
                    autocomplete="off"
                    class="w-full px-4 py-3 text-sm border rounded-xl border-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    disabled={@loading}
                  />
                </div>
                <button
                  type="submit"
                  disabled={@loading}
                  class="flex items-center justify-center w-10 h-10 text-white transition-colors bg-indigo-600 rounded-full hover:bg-indigo-700 disabled:opacity-50"
                >
                  <.icon name="hero-arrow-up" class="w-5 h-5" />
                </button>
              </form>
            </div>
          </div>
        <% else %>
          <%!-- History Tab --%>
          <div class="h-full px-6 py-4 space-y-2 overflow-y-auto">
            <%= if Enum.empty?(@conversations) do %>
              <div class="py-12 text-center text-slate-500">
                <.icon
                  name="hero-chat-bubble-left-right"
                  class="w-12 h-12 mx-auto mb-3 text-slate-300"
                />
                <p class="font-medium">No conversations yet</p>
                <p class="mt-1 text-sm">Start a new chat to get started</p>
              </div>
            <% else %>
              <button
                :for={conv <- @conversations}
                phx-click="load_conversation"
                phx-value-id={conv.id}
                class="w-full px-4 py-3 text-left transition-colors border rounded-lg hover:bg-slate-50 border-border"
              >
                <p class="text-sm font-medium truncate text-slate-900">{conv.title}</p>
                <p class="text-xs text-slate-500 mt-0.5">
                  {Calendar.strftime(conv.inserted_at, "%b %d, %Y at %I:%M %p")}
                </p>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_message_content(content) do
    # Highlight @mentions in content
    content
    |> String.replace(~r/@([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*)/, fn match ->
      "<span class=\"text-indigo-600 font-medium\">#{match}</span>"
    end)
    |> Phoenix.HTML.raw()
  end
end
