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
          suggestion_groups={@suggestion_groups}
          expanded_groups={@expanded_groups}
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

  attr :suggestion_groups, :list, required: true
  attr :expanded_groups, :map, required: true
  attr :loading, :boolean, required: true
  attr :myself, :any, required: true
  attr :patch, :string, required: true
  attr :provider_label, :string, required: true
  attr :submit_class, :string, required: true

  defp suggestions_section(assigns) do
    # Calculate counts for footer
    all_fields = Enum.flat_map(assigns.suggestion_groups, & &1.fields)
    selected_fields = Enum.filter(all_fields, & &1.apply)
    selected_count = length(selected_fields)
    total_groups = length(assigns.suggestion_groups)

    groups_with_selections =
      Enum.count(assigns.suggestion_groups, fn group ->
        Enum.any?(group.fields, & &1.apply)
      end)

    assigns =
      assigns
      |> assign(:selected_count, selected_count)
      |> assign(:total_groups, total_groups)
      |> assign(:groups_with_selections, groups_with_selections)

    ~H"""
    <div class="space-y-4">
      <%= if @loading and Enum.empty?(@suggestion_groups) do %>
        <div class="py-8 text-center text-content-tertiary">
          <.icon name="hero-arrow-path" class="w-6 h-6 mx-auto mb-2 animate-spin" />
          <p>Generating suggestions...</p>
        </div>
      <% else %>
        <%= if Enum.empty?(@suggestion_groups) do %>
          <.empty_state
            message="No update suggestions found from this meeting."
            submessage="The AI didn't detect any new contact information in the transcript."
          />
        <% else %>
          <form phx-submit="apply_updates" phx-change="toggle_suggestion" phx-target={@myself}>
            <div class="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
              <.field_group_section
                :for={group <- @suggestion_groups}
                group={group}
                expanded={Map.get(@expanded_groups, group_id(group), true)}
                target={@myself}
              />
            </div>

            <.modal_footer
              cancel_patch={@patch}
              submit_text={"Update #{@provider_label}"}
              submit_class={@submit_class}
              disabled={@selected_count == 0}
              loading={@loading}
              loading_text="Updating..."
              info_text={"#{@groups_with_selections} objects, #{@selected_count} fields in 1 integration selected to update"}
            />
          </form>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp group_id(group) do
    id = group[:id] || group.id
    id || group.name |> String.downcase() |> String.replace(~r/\s+/, "_")
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:step, fn -> :search end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:contacts, fn -> [] end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:suggestion_groups, fn -> [] end)
      |> assign_new(:expanded_groups, fn -> %{} end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:searching, fn -> false end)
      |> assign_new(:dropdown_open, fn -> false end)
      |> assign_new(:error, fn -> nil end)
      |> maybe_group_suggestions(assigns)

    {:ok, socket}
  end

  # Group flat suggestions into grouped structure for display
  defp maybe_group_suggestions(socket, %{suggestions: suggestions})
       when is_list(suggestions) and suggestions != [] do
    # Mark all suggestions as selected by default
    suggestions_with_apply = Enum.map(suggestions, &Map.put(&1, :apply, true))

    # Group by category or create a default group
    groups = group_suggestions_by_category(suggestions_with_apply)

    # Initialize all groups as expanded
    expanded_groups =
      groups
      |> Enum.map(fn group -> {group_id(group), true} end)
      |> Map.new()

    assign(socket,
      suggestions: suggestions_with_apply,
      suggestion_groups: groups,
      expanded_groups: Map.merge(socket.assigns.expanded_groups, expanded_groups)
    )
  end

  defp maybe_group_suggestions(socket, _assigns), do: socket

  defp group_suggestions_by_category(suggestions) do
    # Group by :category field if present, otherwise group by first letter of label
    suggestions
    |> Enum.group_by(fn suggestion ->
      suggestion[:category] || suggestion[:group] || humanize_field_category(suggestion.field)
    end)
    |> Enum.map(fn {name, fields} ->
      %{
        id: name |> String.downcase() |> String.replace(~r/\s+/, "_"),
        name: name,
        fields: fields
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp humanize_field_category(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> List.first()
    |> String.capitalize()
    |> Kernel.<>(" fields")
  end

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
       suggestion_groups: [],
       expanded_groups: %{},
       loading: false,
       searching: false,
       dropdown_open: false,
       contacts: [],
       query: "",
       error: nil
     )}
  end

  @impl true
  def handle_event("toggle_expand", %{"group" => group_id}, socket) do
    expanded_groups = socket.assigns.expanded_groups
    current_state = Map.get(expanded_groups, group_id, true)
    updated_expanded = Map.put(expanded_groups, group_id, !current_state)

    {:noreply, assign(socket, expanded_groups: updated_expanded)}
  end

  @impl true
  def handle_event("toggle_group", %{"group" => group_id}, socket) do
    # Toggle all fields in the group on/off
    updated_groups =
      Enum.map(socket.assigns.suggestion_groups, fn group ->
        if group_id(group) == group_id do
          # Check current state - if all selected, deselect all; otherwise select all
          all_selected = Enum.all?(group.fields, & &1.apply)
          new_apply = !all_selected

          updated_fields = Enum.map(group.fields, &Map.put(&1, :apply, new_apply))
          %{group | fields: updated_fields}
        else
          group
        end
      end)

    # Also update the flat suggestions list for form submission
    updated_suggestions =
      updated_groups
      |> Enum.flat_map(& &1.fields)

    {:noreply,
     assign(socket, suggestion_groups: updated_groups, suggestions: updated_suggestions)}
  end

  @impl true
  def handle_event("toggle_suggestion", params, socket) do
    # Form sends only checked checkboxes; ensure "apply" is a map (keys = checked field names).
    applied_fields = params["apply"]
    applied_fields = if is_map(applied_fields), do: applied_fields, else: %{}
    checked_set = applied_fields |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()

    values = params["values"]
    values = if is_map(values), do: values, else: %{}

    # Get group toggles - which groups have their header checkbox checked NOW
    group_toggles = params["group_toggle"]
    group_toggles = if is_map(group_toggles), do: group_toggles, else: %{}
    checked_groups = group_toggles |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()

    # Update the grouped structure - detect group state changes
    updated_groups =
      Enum.map(socket.assigns.suggestion_groups, fn group ->
        gid = group_id(group)
        group_is_checked = MapSet.member?(checked_groups, gid)

        # Check previous state - was any field in this group selected before?
        was_group_active = Enum.any?(group.fields, & &1.apply)

        updated_fields =
          Enum.map(group.fields, fn field ->
            field_key = to_string(field.field)

            # Determine if field should be selected:
            apply? =
              cond do
                # Group unchecked -> deselect all
                not group_is_checked ->
                  false

                # Group newly checked (was inactive, now active) -> select all
                group_is_checked and not was_group_active ->
                  true

                # Group was already active -> use individual checkbox state
                true ->
                  MapSet.member?(checked_set, field_key)
              end

            new_value = Map.get(values, field_key) || Map.get(values, field.field)

            field =
              if new_value != nil do
                %{field | new_value: new_value}
              else
                field
              end

            %{field | apply: apply?}
          end)

        %{group | fields: updated_fields}
      end)

    # Update the flat suggestions list to stay in sync
    updated_suggestions = Enum.flat_map(updated_groups, & &1.fields)

    {:noreply,
     assign(socket, suggestions: updated_suggestions, suggestion_groups: updated_groups)}
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
