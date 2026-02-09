defmodule SocialScribeWeb.MeetingLive.CrmHandlers do
  @moduledoc """
  Handles CRM-related events (HubSpot, Salesforce, etc.) for MeetingLive.
  """
  import Phoenix.LiveView
  use Phoenix.Component
  use SocialScribeWeb, :verified_routes

  alias SocialScribe.HubspotApiBehaviour, as: HubspotApi
  alias SocialScribe.HubspotSuggestions
  alias SocialScribe.Crm.Registry
  alias SocialScribe.Crm.Suggestions, as: CrmSuggestions

  # === Old HubSpot-specific handlers (kept for backward compat until Phase 6) ===

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

  def handle_info({:apply_hubspot_updates, updates, contact, credential}, socket) do
    case HubspotApi.update_contact(credential, contact.id, updates) do
      {:ok, _updated_contact} ->
        socket =
          socket
          |> put_flash(:success, "Successfully updated #{map_size(updates)} field(s) in HubSpot")
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

  def handle_info({:crm_search, provider, query, credential}, socket) do
    adapter = Application.get_env(:social_scribe, :crm_api) || Registry.adapter_for!(provider)

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

  def handle_info({:crm_apply_updates, provider, updates, contact, credential}, socket) do
    adapter = Application.get_env(:social_scribe, :crm_api) || Registry.adapter_for!(provider)
    provider_label = Registry.provider_label(provider)

    case adapter.update_contact(credential, contact.id, updates) do
      {:ok, _updated_contact} ->
        socket =
          socket
          |> put_flash(
            :success,
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

  defp normalize_contact(contact) do
    # Contact is already formatted with atom keys from HubspotApi.format_contact
    contact
  end
end
