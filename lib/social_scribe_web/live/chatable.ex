defmodule SocialScribeWeb.Chatable do
  @moduledoc """
  A module that can be `use`d in LiveViews that render the ChatPopup component.
  It adds the necessary `handle_info` clauses to forward chat messages from
  async tasks to the ChatPopup component.

  ## Example

      defmodule MyLiveView do
        use SocialScribeWeb, :live_view
        use SocialScribeWeb.Chatable

        # ... rest of your LiveView code
      end
  """
  defmacro __using__(_opts) do
    quote do
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
        send_update(SocialScribeWeb.ChatPopup,
          id: "chat-popup",
          chat_error: {conversation_id, error}
        )

        {:noreply, socket}
      end

      defoverridable handle_info: 2
    end
  end
end
