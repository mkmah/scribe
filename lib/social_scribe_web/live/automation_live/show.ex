defmodule SocialScribeWeb.AutomationLive.Show do
  use SocialScribeWeb, :live_view

  alias SocialScribe.Automations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:automation, Automations.get_automation!(id))}
  end

  @impl true
  def handle_event("toggle_automation", %{"id" => id}, socket) do
    automation = Automations.get_automation!(id)

    case Automations.update_automation(automation, %{is_active: !automation.is_active}) do
      {:ok, updated_automation} ->
        {:noreply, assign(socket, :automation, updated_automation)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :danger, "You can only have one active automation per platform")}
    end
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

  defp page_title(:show), do: "Show Automation"
  defp page_title(:edit), do: "Edit Automation"
end
