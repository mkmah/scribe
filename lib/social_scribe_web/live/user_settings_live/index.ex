defmodule SocialScribeWeb.UserSettingsLive.Index do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.Components.IntegrationCard, only: [integration_card: 1]

  alias SocialScribe.Accounts
  alias SocialScribe.Bots

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    google_accounts = Accounts.list_user_credentials(current_user, provider: "google")

    linkedin_accounts = Accounts.list_user_credentials(current_user, provider: "linkedin")

    facebook_accounts = Accounts.list_user_credentials(current_user, provider: "facebook")

    hubspot_accounts = Accounts.list_user_credentials(current_user, provider: "hubspot")

    salesforce_accounts = Accounts.list_user_credentials(current_user, provider: "salesforce")

    user_bot_preference =
      Bots.get_user_bot_preference(current_user.id) || %Bots.UserBotPreference{}

    changeset = Bots.change_user_bot_preference(user_bot_preference)

    socket =
      socket
      |> assign(:page_title, "User Settings")
      |> assign(:google_accounts, google_accounts)
      |> assign(:linkedin_accounts, linkedin_accounts)
      |> assign(:facebook_accounts, facebook_accounts)
      |> assign(:hubspot_accounts, hubspot_accounts)
      |> assign(:salesforce_accounts, salesforce_accounts)
      |> assign(:user_bot_preference, user_bot_preference)
      |> assign(:user_bot_preference_form, to_form(changeset))
      |> assign(:timezone_mode, "browser")
      |> assign(:selected_timezone, "America/New_York")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    case socket.assigns.live_action do
      :facebook_pages ->
        facebook_page_options =
          socket.assigns.current_user
          |> Accounts.list_linked_facebook_pages()
          |> Enum.map(&{&1.page_name, &1.id})

        socket =
          socket
          |> assign(:facebook_page_options, facebook_page_options)
          |> assign(:facebook_page_form, to_form(%{"facebook_page" => ""}))

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_user_bot_preference", %{"user_bot_preference" => params}, socket) do
    changeset =
      socket.assigns.user_bot_preference
      |> Bots.change_user_bot_preference(params)

    {:noreply, assign(socket, :user_bot_preference_form, to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("update_user_bot_preference", %{"user_bot_preference" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    case create_or_update_user_bot_preference(socket.assigns.user_bot_preference, params) do
      {:ok, bot_preference} ->
        # Add a timestamp to force LiveView to detect the change
        flash_timestamp = System.system_time(:millisecond)

        {:noreply,
         socket
         |> assign(:user_bot_preference, bot_preference)
         |> assign(:flash_timestamp, flash_timestamp)
         |> put_flash(:success, "Bot preference updated successfully")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :user_bot_preference_form, to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("toggle_timezone_mode", _params, socket) do
    new_mode = if socket.assigns.timezone_mode == "browser", do: "manual", else: "browser"
    {:noreply, assign(socket, :timezone_mode, new_mode)}
  end

  @impl true
  def handle_event("update_timezone", %{"timezone" => timezone}, socket) do
    {:noreply, assign(socket, :selected_timezone, timezone)}
  end

  @impl true
  def handle_event("disconnect_account", %{"id" => id}, socket) do
    credential = Accounts.get_user_credential!(id)

    # Ensure the credential belongs to the current user
    if credential.user_id == socket.assigns.current_user.id do
      case Accounts.delete_user_credential(credential) do
        {:ok, _} ->
          provider = credential.provider
          assign_key = String.to_existing_atom("#{provider}_accounts")

          updated_accounts =
            Accounts.list_user_credentials(socket.assigns.current_user, provider: provider)

          {:noreply,
           socket
           |> assign(assign_key, updated_accounts)
           |> put_flash(:success, "#{String.capitalize(provider)} account disconnected.")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :danger, "Could not disconnect account.")}
      end
    else
      {:noreply, put_flash(socket, :danger, "Unauthorized.")}
    end
  end

  @impl true
  def handle_event("select_facebook_page", %{"facebook_page" => facebook_page}, socket) do
    facebook_page_credential = Accounts.get_facebook_page_credential!(facebook_page)

    case Accounts.update_facebook_page_credential(facebook_page_credential, %{selected: true}) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:success, "Facebook page selected successfully")
          |> push_navigate(to: ~p"/dashboard/settings")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  defp create_or_update_user_bot_preference(bot_preference, params) do
    case bot_preference do
      %Bots.UserBotPreference{id: nil} ->
        Bots.create_user_bot_preference(params)

      bot_preference ->
        Bots.update_user_bot_preference(bot_preference, params)
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

  def timezone_options do
    [
      {"Americas",
       [
         {"America/New_York (EST/EDT)", "America/New_York"},
         {"America/Chicago (CST/CDT)", "America/Chicago"},
         {"America/Denver (MST/MDT)", "America/Denver"},
         {"America/Los_Angeles (PST/PDT)", "America/Los_Angeles"},
         {"America/Anchorage (AKST)", "America/Anchorage"},
         {"America/Sao_Paulo (BRT)", "America/Sao_Paulo"},
         {"America/Buenos_Aires (ART)", "America/Argentina/Buenos_Aires"},
         {"America/Toronto (EST/EDT)", "America/Toronto"},
         {"America/Vancouver (PST/PDT)", "America/Vancouver"}
       ]},
      {"Europe",
       [
         {"Europe/London (GMT/BST)", "Europe/London"},
         {"Europe/Berlin (CET/CEST)", "Europe/Berlin"},
         {"Europe/Paris (CET/CEST)", "Europe/Paris"},
         {"Europe/Amsterdam (CET/CEST)", "Europe/Amsterdam"},
         {"Europe/Zurich (CET/CEST)", "Europe/Zurich"},
         {"Europe/Moscow (MSK)", "Europe/Moscow"},
         {"Europe/Istanbul (TRT)", "Europe/Istanbul"}
       ]},
      {"Asia & Pacific",
       [
         {"Asia/Dubai (GST)", "Asia/Dubai"},
         {"Asia/Kolkata (IST)", "Asia/Kolkata"},
         {"Asia/Shanghai (CST)", "Asia/Shanghai"},
         {"Asia/Tokyo (JST)", "Asia/Tokyo"},
         {"Asia/Singapore (SGT)", "Asia/Singapore"},
         {"Asia/Seoul (KST)", "Asia/Seoul"},
         {"Australia/Sydney (AEST/AEDT)", "Australia/Sydney"},
         {"Pacific/Auckland (NZST/NZDT)", "Pacific/Auckland"},
         {"Pacific/Honolulu (HST)", "Pacific/Honolulu"}
       ]},
      {"Africa",
       [
         {"Africa/Cairo (EET)", "Africa/Cairo"},
         {"Africa/Lagos (WAT)", "Africa/Lagos"},
         {"Africa/Johannesburg (SAST)", "Africa/Johannesburg"},
         {"Africa/Nairobi (EAT)", "Africa/Nairobi"}
       ]}
    ]
  end

  attr :name, :string, required: true
  attr :description, :string, required: true
  attr :accounts, :list, default: []
  attr :icon, :atom, required: true
  attr :connect_path, :string, required: true

  attr :disconnect_confirm_message, :string,
    default: "Are you sure you want to disconnect this account?"

  attr :show_action_when_connected, :boolean, default: true
  slot :extra_actions

  def integration_section(assigns) do
    ~H"""
    <.integration_card
      name={@name}
      description={@description}
      connected={not Enum.empty?(@accounts)}
      icon={@icon}
    >
      <:connection_list :if={not Enum.empty?(@accounts)}>
        <%= for account <- @accounts do %>
          <div class="flex items-center justify-between px-3 py-2 rounded-md bg-muted">
            <p class="text-sm">{account.email || account.uid}</p>
            <div class="flex items-center gap-2">
              {render_slot(@extra_actions, account)}

              <.icon_button
                variant="destructive"
                size="xs"
                phx-click="disconnect_account"
                phx-value-id={account.id}
                data-confirm={@disconnect_confirm_message}
              >
                <.trash class="w-2 h-2" />
              </.icon_button>
            </div>
          </div>
        <% end %>
      </:connection_list>

      <:action :if={
        Enum.empty?(@accounts) or
          @show_action_when_connected
      }>
        <.link href={@connect_path}>
          <.button variant="outline" size="sm">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" />
            {if Enum.empty?(@accounts), do: "Connect #{@name}", else: "Connect another #{@name}"}
          </.button>
        </.link>
      </:action>
    </.integration_card>
    """
  end
end
