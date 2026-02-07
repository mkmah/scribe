defmodule SocialScribeWeb.MeetingLive.Show do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton
  import SocialScribeWeb.ModalComponents, only: [hubspot_modal: 1]

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.Accounts
  alias SocialScribe.HubspotApiBehaviour, as: HubspotApi
  alias SocialScribe.HubspotSuggestions
  alias SocialScribe.Crm.Registry
  alias SocialScribe.Crm.Suggestions, as: CrmSuggestions

  @impl true
  def mount(%{"id" => meeting_id}, _session, socket) do
    meeting = Meetings.get_meeting_with_details(meeting_id)

    user_has_automations =
      Automations.list_active_user_automations(socket.assigns.current_user.id)
      |> length()
      |> Kernel.>(0)

    automation_results = Automations.list_automation_results_for_meeting(meeting_id)

    if meeting.calendar_event.user_id != socket.assigns.current_user.id do
      socket =
        socket
        |> put_flash(:error, "You do not have permission to view this meeting.")
        |> redirect(to: ~p"/dashboard/meetings")

      {:error, socket}
    else
      # Old HubSpot credential (for backward compatibility)
      hubspot_credential = Accounts.get_user_hubspot_credential(socket.assigns.current_user.id)

      # Build CRM credentials map for all registered providers
      crm_credentials = build_crm_credentials(socket.assigns.current_user.id)

      socket =
        socket
        |> assign(:page_title, "Meeting Details: #{meeting.title}")
        |> assign(:meeting, meeting)
        |> assign(:automation_results, automation_results)
        |> assign(:user_has_automations, user_has_automations)
        |> assign(:hubspot_credential, hubspot_credential)
        |> assign(:crm_credentials, crm_credentials)
        |> assign(
          :follow_up_email_form,
          to_form(%{
            "follow_up_email" => ""
          })
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"automation_result_id" => automation_result_id}, _uri, socket) do
    automation_result = Automations.get_automation_result!(automation_result_id)
    automation = Automations.get_automation!(automation_result.automation_id)

    socket =
      socket
      |> assign(:automation_result, automation_result)
      |> assign(:automation, automation)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate-follow-up-email", params, socket) do
    socket =
      socket
      |> assign(:follow_up_email_form, to_form(params))

    {:noreply, socket}
  end

  # === Old HubSpot-specific handlers (kept for backward compat until Phase 6) ===

  @impl true
  def handle_info({:hubspot_search, query, credential}, socket) do
    case HubspotApi.search_contacts(credential, query) do
      {:ok, contacts} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          contacts: contacts,
          searching: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: "Failed to search contacts: #{inspect(reason)}",
          searching: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_suggestions, contact, meeting, _credential}, socket) do
    case HubspotSuggestions.generate_suggestions_from_meeting(meeting) do
      {:ok, suggestions} ->
        merged = HubspotSuggestions.merge_with_contact(suggestions, normalize_contact(contact))

        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          step: :suggestions,
          suggestions: merged,
          loading: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: "Failed to generate suggestions: #{inspect(reason)}",
          loading: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:apply_hubspot_updates, updates, contact, credential}, socket) do
    case HubspotApi.update_contact(credential, contact.id, updates) do
      {:ok, _updated_contact} ->
        socket =
          socket
          |> put_flash(:info, "Successfully updated #{map_size(updates)} field(s) in HubSpot")
          |> push_patch(to: ~p"/dashboard/meetings/#{socket.assigns.meeting}")

        {:noreply, socket}

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: "Failed to update contact: #{inspect(reason)}",
          loading: false
        )

        {:noreply, socket}
    end
  end

  # === Generic CRM handlers ===

  @impl true
  def handle_info({:crm_search, provider, query, credential}, socket) do
    adapter = Registry.adapter_for!(provider)

    case adapter.search_contacts(credential, query) do
      {:ok, contacts} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "crm-modal-#{provider}",
          contacts: contacts,
          searching: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "crm-modal-#{provider}",
          error: "Failed to search contacts: #{inspect(reason)}",
          searching: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:crm_generate_suggestions, provider, contact, meeting, _credential}, socket) do
    case CrmSuggestions.generate_from_meeting(meeting) do
      {:ok, suggestions} ->
        merged = CrmSuggestions.merge_with_contact(suggestions, contact)

        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "crm-modal-#{provider}",
          step: :suggestions,
          suggestions: merged,
          loading: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "crm-modal-#{provider}",
          error: "Failed to generate suggestions: #{inspect(reason)}",
          loading: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:crm_apply_updates, provider, updates, contact, credential}, socket) do
    adapter = Registry.adapter_for!(provider)
    provider_label = Registry.provider_label(provider)

    case adapter.update_contact(credential, contact.id, updates) do
      {:ok, _updated_contact} ->
        socket =
          socket
          |> put_flash(
            :info,
            "Successfully updated #{map_size(updates)} field(s) in #{provider_label}"
          )
          |> push_patch(to: ~p"/dashboard/meetings/#{socket.assigns.meeting}")

        {:noreply, socket}

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.CrmModalComponent,
          id: "crm-modal-#{provider}",
          error: "Failed to update contact: #{inspect(reason)}",
          loading: false
        )

        {:noreply, socket}
    end
  end

  defp build_crm_credentials(user_id) do
    Registry.crm_providers()
    |> Enum.reduce(%{}, fn provider, acc ->
      case Accounts.get_user_crm_credential(user_id, provider) do
        nil -> acc
        credential -> Map.put(acc, provider, credential)
      end
    end)
  end

  defp normalize_contact(contact) do
    # Contact is already formatted with atom keys from HubspotApi.format_contact
    contact
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes > 0 && remaining_seconds > 0 -> "#{minutes} min #{remaining_seconds} sec"
      minutes > 0 -> "#{minutes} min"
      seconds > 0 -> "#{seconds} sec"
      true -> "Less than a second"
    end
  end

  attr :meeting_transcript, :map, required: true

  defp transcript_content(assigns) do
    has_transcript =
      assigns.meeting_transcript &&
        assigns.meeting_transcript.content &&
        Map.get(assigns.meeting_transcript.content, "data") &&
        Enum.any?(Map.get(assigns.meeting_transcript.content, "data"))

    assigns =
      assigns
      |> assign(:has_transcript, has_transcript)

    ~H"""
    <section class="bg-white dark:bg-[#232323] rounded-lg border border-gray-200 dark:border-[#2e2e2e] overflow-hidden">
      <div class="px-5 py-3 border-b border-gray-100 dark:border-[#2e2e2e] flex items-center gap-2">
        <.icon name="hero-chat-bubble-bottom-center-text" class="h-4 w-4 text-gray-400" />
        <h2 class="text-sm font-semibold text-gray-900 dark:text-gray-100">Transcript</h2>
      </div>
      <div class="p-5 h-96 overflow-y-auto scrollbar-thin">
        <%= if @has_transcript do %>
          <div class="space-y-3">
            <div :for={segment <- @meeting_transcript.content["data"]} class="flex gap-3">
              <div class="flex-shrink-0 w-6 h-6 rounded-full bg-brand-500/10 dark:bg-brand-500/20 flex items-center justify-center mt-0.5">
                <span class="text-[9px] font-bold text-brand-700 dark:text-brand-400">
                  {String.at(segment["speaker"] || "?", 0) |> String.upcase()}
                </span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-semibold text-brand-600 dark:text-brand-400 mb-0.5">
                  {segment["speaker"] || "Unknown Speaker"}
                </p>
                <p class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">
                  {Enum.map_join(segment["words"] || [], " ", & &1["text"])}
                </p>
              </div>
            </div>
          </div>
        <% else %>
          <div class="flex items-center justify-center h-full">
            <p class="text-sm text-gray-400 dark:text-gray-500">Transcript not available.</p>
          </div>
        <% end %>
      </div>
    </section>
    """
  end
end
