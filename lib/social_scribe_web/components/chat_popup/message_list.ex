defmodule SocialScribeWeb.ChatPopup.MessageList do
  @moduledoc """
  Component for rendering chat messages in the ChatPopup.
  Handles both user and assistant message rendering with mention support.
  """
  use Phoenix.Component

  import SocialScribeWeb.UI.DateTime
  alias SocialScribeWeb.Helpers.Markdown

  def message_list(assigns) do
    ~H"""
    <div
      id="chat-popup-messages"
      phx-hook="ScrollToBottom"
      class="flex-1 px-5 py-4 space-y-4 overflow-y-auto scrollbar-thin"
    >
      <%!-- Timestamp centered on separator line --%>
      <%= if @current_conversation do %>
        <div class="flex items-center gap-3 mb-2">
          <div class="flex-1 h-px bg-border"></div>
          <span class="text-xs text-muted-foreground whitespace-nowrap">
            <.date_time datetime={@current_conversation.inserted_at} format="datetime" />
          </span>
          <div class="flex-1 h-px bg-border"></div>
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
                <div class="text-sm leading-relaxed text-foreground">
                  <.message_content_block content={message.content} role={:user} />
                </div>
              </div>
            </div>
          <% else %>
            <div class="flex justify-start">
              <div class="max-w-[85%]">
                <div class="text-sm leading-relaxed text-gray-700 dark:text-gray-300 markdown-content">
                  <.message_content_block content={message.content} role={:assistant} />
                </div>
                <%!-- Sources below assistant replies --%>
                <.sources_badge />
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
    """
  end

  defp message_content_block(assigns) do
    assigns = assign(assigns, :segments, message_content_segments(assigns.content))

    ~H"""
    <%= if @role == :assistant do %>
      <%!-- Render markdown for assistant messages --%>
      <.render_assistant_markdown content={@content} />
    <% else %>
      <%!-- Render with mention pills for user messages --%>
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
    <% end %>
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

  # Render markdown content to HTML using Earmark
  defp render_assistant_markdown(assigns) do
    content = assigns.content
    html = Markdown.render_markdown(content)
    assigns = assign(assigns, :html, html)

    ~H"""
    <div>{@html}</div>
    """
  end

  def sources_badge(assigns) do
    ~H"""
    <div class="flex items-center gap-1.5">
      <span class="text-xs text-muted-foreground/60">Sources</span>
      <div class="flex -space-x-1">
        <div
          class="w-4 h-4 rounded-full bg-[#EA4335] flex items-center justify-center ring-2 ring-white dark:ring-card z-30"
          title="Gmail"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-2.5 h-2.5" fill="white">
            <path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" />
          </svg>
        </div>
        <div
          class="w-4 h-4 rounded-full bg-[#FF7A59] flex items-center justify-center ring-2 ring-white dark:ring-card z-20"
          title="HubSpot"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-2.5 h-2.5" fill="white">
            <path d="M18.164 7.93V3.836a1.5 1.5 0 0 0-3 0v7.5h-1.5V2.336a1.5 1.5 0 0 0-3 0v9h-1.5v-7.5a1.5 1.5 0 0 0-3 0v9c0 3.244 2.175 5.977 5.143 6.807L10.664 22.5a1.5 1.5 0 0 0 3 0v-1.5c3.728 0 6.75-3.022 6.75-6.75V7.93h-2.25z" />
          </svg>
        </div>
        <div
          class="w-4 h-4 rounded-full bg-[#00A1E0] flex items-center justify-center ring-2 ring-white dark:ring-card z-10"
          title="Salesforce"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-2.5 h-2.5" fill="white">
            <path d="M17.05 2.55c-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52l-1.67 1.67c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52l-1.67 1.67c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.13.57.66.96 1.24.92.28-.02.54-.14.74-.33l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.04-.19-.13-.37-.26-.52l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.13-.57-.66-.96-1.24-.92-.28.02-.54.14-.74.33l-1.67 1.67c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52L6.78 10.6c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.13.57.66.96 1.24.92.28-.02.54-.14.74-.33l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.04-.19-.13-.37-.26-.52l1.67-1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.13-.57-.66-.96-1.24-.92-.28.02-.54.14-.74.33L9.06 6.09c-.26-.12-.56-.16-.85-.1-.64.15-1.05.76-.92 1.4.04.19.13.37.26.52l1.67 1.67c.26.12.56.16.85.1.64-.15 1.05-.76.92-1.4-.04-.19-.13-.37-.26-.52l1.67-1.67c-.14-.15-.22-.33-.26-.52-.13-.64.28-1.25.92-1.4.58-.04 1.11.35 1.24.92.04.19-.02.39-.13.57l-1.67 1.67c.14.15.22.33.26.52.13.64-.28 1.25-.92 1.4-.58.04-1.11-.35-1.24-.92-.04-.19.02-.39.13-.57L7.44 5.33c.14-.15.22-.33.26-.52.13-.64-.28-1.25-.92-1.4-.58-.04-1.11.35-1.24.92-.04.19.02.39.13.57l1.67 1.67c-.14.15-.22.33-.26.52-.13.64.28 1.25.92 1.4.58.04 1.11-.35 1.24-.92.04-.19-.02-.39-.13-.57l-1.67-1.67c.14-.15.22-.33.26-.52.13-.64-.28-1.25-.92-1.4-.58-.04-1.11.35-1.24.92-.04.19.02.39.13.57l1.67 1.67c-.14.15-.22.33-.26.52-.13.64.28 1.25.92 1.4.58.04 1.11-.35 1.24-.92.04-.19-.02-.39-.13-.57L5.22 3.98c.14-.15.22-.33.26-.52.13-.64-.28-1.25-.92-1.4-.58-.04-1.11.35-1.24.92-.04.19.02.39.13.57l1.67 1.67c-.14.15-.22.33-.26.52-.13.64.28 1.25.92 1.4.58.04 1.11-.35 1.24-.92.04-.19-.02-.39-.13-.57l-1.67-1.67z" />
          </svg>
        </div>
      </div>
    </div>
    """
  end
end
