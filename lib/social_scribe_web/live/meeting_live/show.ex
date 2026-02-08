defmodule SocialScribeWeb.MeetingLive.Show do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.Accounts
  alias SocialScribe.HubspotApiBehaviour, as: HubspotApi
  alias SocialScribe.HubspotSuggestions
  alias SocialScribe.Crm.Registry
  alias SocialScribe.Crm.Suggestions, as: CrmSuggestions
  alias SocialScribe.Workers.AIContentGenerationWorker

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
        |> assign(:regenerating, false)
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

  @impl true
  def handle_event("regenerate-automations", _params, socket) do
    meeting = socket.assigns.meeting
    user_id = socket.assigns.current_user.id

    case AIContentGenerationWorker.enqueue_automation_regeneration(meeting.id, user_id) do
      {:ok, _job} ->
        socket =
          socket
          |> put_flash(:info, "Regeneration started. Please wait...")
          |> assign(:regenerating, true)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to start regeneration: #{inspect(reason)}")

        {:noreply, socket}
    end
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

  # Returns true if all automation results have failed status
  defp has_only_failed_results(automation_results) do
    Enum.all?(automation_results, fn result -> result.status == "generation_failed" end)
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

  # Generate consistent color for a participant based on their name
  def participant_color(name) do
    colors = [
      # Pastel/soft colors that work well in both light and dark modes
      %{bg: "bg-blue-100 dark:bg-blue-900/30", text: "text-blue-700 dark:text-blue-400"},
      %{bg: "bg-emerald-100 dark:bg-emerald-900/30", text: "text-emerald-700 dark:text-emerald-400"},
      %{bg: "bg-violet-100 dark:bg-violet-900/30", text: "text-violet-700 dark:text-violet-400"},
      %{bg: "bg-amber-100 dark:bg-amber-900/30", text: "text-amber-700 dark:text-amber-400"},
      %{bg: "bg-rose-100 dark:bg-rose-900/30", text: "text-rose-700 dark:text-rose-400"},
      %{bg: "bg-cyan-100 dark:bg-cyan-900/30", text: "text-cyan-700 dark:text-cyan-400"},
      %{bg: "bg-fuchsia-100 dark:bg-fuchsia-900/30", text: "text-fuchsia-700 dark:text-fuchsia-400"},
      %{bg: "bg-orange-100 dark:bg-orange-900/30", text: "text-orange-700 dark:text-orange-400"},
      %{bg: "bg-teal-100 dark:bg-teal-900/30", text: "text-teal-700 dark:text-teal-400"},
      %{bg: "bg-pink-100 dark:bg-pink-900/30", text: "text-pink-700 dark:text-pink-400"},
      %{bg: "bg-indigo-100 dark:bg-indigo-900/30", text: "text-indigo-700 dark:text-indigo-400"},
      %{bg: "bg-lime-100 dark:bg-lime-900/30", text: "text-lime-700 dark:text-lime-400"}
    ]

    # Use a simple hash to pick a consistent color for the same name
    index =
      name
      |> :erlang.phash2()
      |> rem(length(colors))

    Enum.at(colors, index)
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
    <div class="overflow-y-auto h-96 scrollbar-thin">
      <%= if @has_transcript do %>
        <div class="space-y-2">
          <div :for={segment <- @meeting_transcript.content["data"]} class="flex gap-3">
            <% color = participant_color(segment["participant"]["name"]) %>
            <div class={"flex-shrink-0 w-6 h-6 rounded-full #{color.bg} flex items-center justify-center mt-0.5"}>
              <span class="text-[8px] font-bold text-gray-700 dark:text-gray-300">
                {String.at(segment["participant"]["name"] || "?", 0) |> String.upcase()}
              </span>
            </div>
            <div class="flex-1 min-w-0">
              <p class={"font-semibold mb-0.5 #{color.text}"}>
                {segment["participant"]["name"] || "Unknown Participant"}
              </p>
              <p class="text-sm leading-relaxed text-gray-700 dark:text-gray-300">
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
    """
  end
end
