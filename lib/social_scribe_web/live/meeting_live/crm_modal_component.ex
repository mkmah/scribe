defmodule SocialScribeWeb.MeetingLive.CrmModalComponent do
  @moduledoc """
  Generic CRM modal component for searching contacts, generating suggestions,
  and applying updates. Works with any CRM provider (HubSpot, Salesforce, etc.)
  by receiving a `provider` assign.
  """

  use SocialScribeWeb, :live_component

  import SocialScribeWeb.ModalComponents

  alias SocialScribe.Crm.Registry

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :patch, ~p"/dashboard/meetings/#{assigns.meeting}")
    assigns = assign_new(assigns, :modal_id, fn -> "crm-modal-wrapper" end)
    provider_label = Registry.provider_label(assigns.provider)

    assigns =
      assigns
      |> assign(:provider_label, provider_label)
      |> assign(:submit_class, provider_submit_class(assigns.provider))

    ~H"""
    <div class="space-y-4">
      <p
        id={"#{@modal_id}-description"}
        class="mt-2 text-sm font-light leading-6 text-content-tertiary"
      >
        Here are suggested updates to sync with your integrations based on this meeting
      </p>

      <.contact_select
        selected_contact={@selected_contact}
        contacts={@contacts}
        loading={@searching}
        open={@dropdown_open}
        query={@query}
        target={@myself}
        error={@error}
      />

      <%= if @selected_contact do %>
        <.suggestions_section
          suggestions={@suggestions}
          loading={@loading}
          myself={@myself}
          patch={@patch}
          provider_label={@provider_label}
          submit_class={@submit_class}
        />
      <% end %>
    </div>
    """
  end

  attr :suggestions, :list, required: true
  attr :loading, :boolean, required: true
  attr :myself, :any, required: true
  attr :patch, :string, required: true
  attr :provider_label, :string, required: true
  attr :submit_class, :string, required: true

  defp suggestions_section(assigns) do
    assigns = assign(assigns, :selected_count, Enum.count(assigns.suggestions, & &1.apply))

    ~H"""
    <div class="space-y-4">
      <%= if @loading and Enum.empty?(@suggestions) do %>
        <div class="py-8 text-center text-content-tertiary">
          <.icon name="hero-arrow-path" class="w-6 h-6 mx-auto mb-2 animate-spin" />
          <p>Generating suggestions...</p>
        </div>
      <% else %>
        <%= if Enum.empty?(@suggestions) do %>
          <.empty_state
            message="No update suggestions found from this meeting."
            submessage="The AI didn't detect any new contact information in the transcript."
          />
        <% else %>
          <form phx-submit="apply_updates" phx-change="toggle_suggestion" phx-target={@myself}>
            <div class="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
              <.suggestion_card :for={suggestion <- @suggestions} suggestion={suggestion} />
            </div>

            <.modal_footer
              cancel_patch={@patch}
              submit_text="Update"
              submit_class={@submit_class}
              disabled={@selected_count == 0}
              loading={@loading}
              loading_text="Updating..."
              info_text={"1 object, #{@selected_count} fields in 1 integration selected to update"}
            />
          </form>
        <% end %>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_select_all_suggestions(assigns)
      |> assign_new(:step, fn -> :search end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:contacts, fn -> [] end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:searching, fn -> false end)
      |> assign_new(:dropdown_open, fn -> false end)
      |> assign_new(:error, fn -> nil end)

    {:ok, socket}
  end

  defp maybe_select_all_suggestions(socket, %{suggestions: suggestions})
       when is_list(suggestions) do
    assign(socket, suggestions: Enum.map(suggestions, &Map.put(&1, :apply, true)))
  end

  defp maybe_select_all_suggestions(socket, _assigns), do: socket

  defp provider_submit_class("hubspot"), do: "bg-[#ff7a59] hover:bg-[#ff6a45] text-white"
  defp provider_submit_class("salesforce"), do: "bg-[#00a1e0] hover:bg-[#0089c2] text-white"
  defp provider_submit_class(_), do: "bg-primary text-primary-foreground"

  @impl true
  def handle_event("contact_search", %{"value" => query}, socket) do
    query = String.trim(query)

    if String.length(query) >= 2 do
      socket = assign(socket, searching: true, error: nil, query: query, dropdown_open: true)

      send(
        self(),
        {:crm_search, socket.assigns.provider, query, socket.assigns.credential}
      )

      {:noreply, socket}
    else
      {:noreply, assign(socket, query: query, contacts: [], dropdown_open: query != "")}
    end
  end

  @impl true
  def handle_event("open_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: true)}
  end

  @impl true
  def handle_event("close_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: false)}
  end

  @impl true
  def handle_event("toggle_contact_dropdown", _params, socket) do
    if socket.assigns.dropdown_open do
      {:noreply, assign(socket, dropdown_open: false)}
    else
      socket = assign(socket, dropdown_open: true, searching: true)
      contact = socket.assigns.selected_contact

      query =
        contact.display_name ||
          "#{contact.first_name || ""} #{contact.last_name || ""}" |> String.trim()

      send(
        self(),
        {:crm_search, socket.assigns.provider, query, socket.assigns.credential}
      )

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_contact", %{"id" => contact_id}, socket) do
    id_str = to_string(contact_id)
    contact = Enum.find(socket.assigns.contacts, &(to_string(&1.id) == id_str))

    if contact do
      socket =
        assign(socket,
          loading: true,
          selected_contact: contact,
          error: nil,
          dropdown_open: false,
          query: "",
          suggestions: []
        )

      send(
        self(),
        {:crm_generate_suggestions, socket.assigns.provider, contact, socket.assigns.meeting,
         socket.assigns.credential}
      )

      {:noreply, socket}
    else
      {:noreply, assign(socket, error: "Contact not found")}
    end
  end

  @impl true
  def handle_event("clear_contact", _params, socket) do
    {:noreply,
     assign(socket,
       step: :search,
       selected_contact: nil,
       suggestions: [],
       loading: false,
       searching: false,
       dropdown_open: false,
       contacts: [],
       query: "",
       error: nil
     )}
  end

  @impl true
  def handle_event("toggle_suggestion", params, socket) do
    # Form sends only checked checkboxes; ensure "apply" is a map (keys = checked field names).
    applied_fields = params["apply"]
    applied_fields = if is_map(applied_fields), do: applied_fields, else: %{}
    checked_set = applied_fields |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()

    values = params["values"]
    values = if is_map(values), do: values, else: %{}

    updated_suggestions =
      Enum.map(socket.assigns.suggestions, fn suggestion ->
        field_key = to_string(suggestion.field)
        apply? = MapSet.member?(checked_set, field_key)

        new_value =
          Map.get(values, field_key) || Map.get(values, suggestion.field)

        suggestion =
          if new_value != nil do
            %{suggestion | new_value: new_value}
          else
            suggestion
          end

        %{suggestion | apply: apply?}
      end)

    {:noreply, assign(socket, suggestions: updated_suggestions)}
  end

  @impl true
  def handle_event("apply_updates", %{"apply" => selected, "values" => values}, socket) do
    socket = assign(socket, loading: true, error: nil)

    updates =
      selected
      |> Map.keys()
      |> Enum.reduce(%{}, fn field, acc ->
        Map.put(acc, field, Map.get(values, field, ""))
      end)

    send(
      self(),
      {:crm_apply_updates, socket.assigns.provider, updates, socket.assigns.selected_contact,
       socket.assigns.credential}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_updates", _params, socket) do
    {:noreply, assign(socket, error: "Please select at least one field to update")}
  end
end
