defmodule SocialScribeWeb.MeetingLive.Show do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.Accounts
  alias SocialScribe.Crm.Registry
  alias SocialScribe.Workers.AIContentGenerationWorker
  alias SocialScribeWeb.MeetingLive.CrmHandlers

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
      # hubspot_credential = Accounts.get_user_hubspot_credential(socket.assigns.current_user.id)

      # Build CRM credentials map for all registered providers
      crm_credentials = build_crm_credentials(socket.assigns.current_user.id)
      crm_entries = build_crm_entries(crm_credentials)

      socket =
        socket
        |> assign(:page_title, "Meeting Details: #{meeting.title}")
        |> assign(:meeting, meeting)
        |> assign(:automation_results, automation_results)
        |> assign(:user_has_automations, user_has_automations)
        # |> assign(:hubspot_credential, hubspot_credential)
        |> assign(:crm_credentials, crm_credentials)
        |> assign(:crm_entries, crm_entries)
        |> assign(:crm_modal_provider, nil)
        |> assign(:crm_modal_provider_label, nil)
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
  def handle_params(params, _uri, socket) do
    {crm_modal_provider, crm_modal_provider_label} =
      case socket.assigns.live_action do
        :hubspot ->
          {"hubspot", Registry.provider_label("hubspot")}

        :salesforce ->
          {"salesforce", Registry.provider_label("salesforce")}

        :crm ->
          provider = params["provider"]
          {provider, provider && Registry.provider_label(provider)}

        _ ->
          {nil, nil}
      end

    socket =
      socket
      |> assign(:crm_modal_provider, crm_modal_provider)
      |> assign(:crm_modal_provider_label, crm_modal_provider_label)

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

  # === CRM Handlers (Delegated) ===

  @impl true
  def handle_info({:hubspot_search, _, _} = msg, socket), do: CrmHandlers.handle_info(msg, socket)

  @impl true
  def handle_info({:generate_suggestions, _, _, _} = msg, socket),
    do: CrmHandlers.handle_info(msg, socket)

  @impl true
  def handle_info({:apply_hubspot_updates, _, _, _} = msg, socket),
    do: CrmHandlers.handle_info(msg, socket)

  @impl true
  def handle_info({:crm_search, _, _, _} = msg, socket), do: CrmHandlers.handle_info(msg, socket)

  @impl true
  def handle_info({:crm_generate_suggestions, _, _, _, _} = msg, socket),
    do: CrmHandlers.handle_info(msg, socket)

  @impl true
  def handle_info({:crm_apply_updates, _, _, _, _} = msg, socket),
    do: CrmHandlers.handle_info(msg, socket)

  defp build_crm_credentials(user_id) do
    Registry.crm_providers()
    |> Enum.reduce(%{}, fn provider, acc ->
      case Accounts.get_user_crm_credential(user_id, provider) do
        nil -> acc
        credential -> Map.put(acc, provider, credential)
      end
    end)
  end

  defp build_crm_entries(crm_credentials) do
    Enum.map(crm_credentials, fn {provider, _credential} ->
      %{
        provider: provider,
        label: Registry.provider_label(provider),
        button_class: crm_button_class(provider)
      }
    end)
  end

  defp crm_button_class("hubspot"), do: "bg-[#ff7a59] hover:bg-[#ff6a45] text-white"
  defp crm_button_class("salesforce"), do: "bg-[#00a1e0] hover:bg-[#0089c2] text-white"
  defp crm_button_class(_), do: "bg-primary text-primary-foreground hover:bg-primary/90"

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
      %{
        bg: "bg-emerald-100 dark:bg-emerald-900/30",
        text: "text-emerald-700 dark:text-emerald-400"
      },
      %{bg: "bg-violet-100 dark:bg-violet-900/30", text: "text-violet-700 dark:text-violet-400"},
      %{bg: "bg-amber-100 dark:bg-amber-900/30", text: "text-amber-700 dark:text-amber-400"},
      %{bg: "bg-rose-100 dark:bg-rose-900/30", text: "text-rose-700 dark:text-rose-400"},
      %{bg: "bg-cyan-100 dark:bg-cyan-900/30", text: "text-cyan-700 dark:text-cyan-400"},
      %{
        bg: "bg-fuchsia-100 dark:bg-fuchsia-900/30",
        text: "text-fuchsia-700 dark:text-fuchsia-400"
      },
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
