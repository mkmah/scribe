defmodule SocialScribeWeb.ModalComponents do
  @moduledoc """
  Modal-specific components for CRM and HubSpot integrations.
  """
  use Phoenix.Component

  import SocialScribeWeb.UI.Button

  alias SocialScribe.Crm.Contact
  alias SocialScribeWeb.UI.Icon

  # ============================================================================
  # CONTACT SELECT
  # ============================================================================

  attr :selected_contact, :map, default: nil
  attr :contacts, :list, default: []
  attr :loading, :boolean, default: false
  attr :open, :boolean, default: false
  attr :query, :string, default: ""
  attr :target, :any, default: nil
  attr :error, :string, default: nil
  attr :id, :string, default: "contact-select"

  def contact_select(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <label for={"#{@id}-input"} class="block text-sm font-medium text-muted-foreground">
        Select Contact
      </label>
      <div class="relative">
        <%= if @selected_contact do %>
          <button
            type="button"
            phx-click="toggle_contact_dropdown"
            phx-target={@target}
            role="combobox"
            aria-haspopup="listbox"
            aria-expanded={to_string(@open)}
            aria-controls={"#{@id}-listbox"}
            class="relative w-full bg-background border border-input rounded-lg pl-3 pr-10 py-2 text-left cursor-pointer hover:border-ring focus:outline-none focus:ring-2 focus:ring-ring focus:border-ring text-sm transition-colors"
          >
            <span class="flex items-center gap-3">
              <.avatar_fallback name={contact_display_name(@selected_contact)} />
              <span class="block truncate text-foreground">
                {contact_display_name(@selected_contact)}
              </span>
            </span>
            <span class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <Icon.chevron_down class="h-4 w-4 text-muted-foreground" />
            </span>
          </button>
        <% else %>
          <div class="relative">
            <input
              id={"#{@id}-input"}
              type="text"
              name="contact_query"
              value={@query}
              placeholder="Search contacts..."
              phx-keyup="contact_search"
              phx-target={@target}
              phx-focus="open_contact_dropdown"
              phx-debounce="500"
              autocomplete="off"
              role="combobox"
              aria-autocomplete="list"
              aria-expanded={to_string(@open)}
              aria-controls={"#{@id}-listbox"}
              class="w-full bg-background border border-input rounded-lg pl-3 pr-10 py-2 text-sm text-foreground placeholder-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:border-ring transition-colors"
            />
            <span class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <%= if @loading do %>
                <Icon.spinner class="h-4 w-4 text-muted-foreground animate-spin" />
              <% else %>
                <Icon.chevron_down class="h-4 w-4 text-muted-foreground" />
              <% end %>
            </span>
          </div>
        <% end %>

        <div
          :if={@open && (@selected_contact || Enum.any?(@contacts) || @loading || @query != "")}
          id={"#{@id}-listbox"}
          role="listbox"
          phx-click-away="close_contact_dropdown"
          phx-target={@target}
          class="absolute z-10 mt-1.5 w-full bg-background shadow-lg max-h-60 rounded-lg py-1 text-sm ring-1 ring-border overflow-auto"
        >
          <button
            :if={@selected_contact}
            type="button"
            phx-click="clear_contact"
            phx-target={@target}
            role="option"
            aria-selected="false"
            class="w-full text-left px-4 py-2 hover:bg-accent text-sm text-muted-foreground cursor-pointer transition-colors"
          >
            Clear selection
          </button>
          <div :if={@loading} class="px-4 py-2 text-sm text-muted-foreground">
            Searching...
          </div>
          <div
            :if={!@loading && Enum.empty?(@contacts) && @query != ""}
            class="px-4 py-2 text-sm text-muted-foreground"
          >
            No contacts found
          </div>
          <button
            :for={contact <- @contacts}
            type="button"
            phx-click="select_contact"
            phx-value-id={contact.id}
            phx-target={@target}
            role="option"
            aria-selected="false"
            class="w-full text-left px-4 py-2.5 hover:bg-accent flex items-center gap-3 cursor-pointer transition-colors"
          >
            <.avatar_fallback name={contact_display_name(contact)} />
            <div>
              <div class="text-sm font-medium text-foreground">
                {contact_display_name(contact)}
              </div>
              <div class="text-xs text-muted-foreground">
                {contact_email(contact)}
              </div>
            </div>
          </button>
        </div>
      </div>
      <p :if={@error} class="text-sm text-destructive">{@error}</p>
    </div>
    """
  end

  # Crm.Contact struct — use struct field access (structs do not implement Access).
  defp contact_display_name(%Contact{} = contact) do
    contact.display_name || contact.email || "Unknown"
  end

  # Plain map (e.g. HubSpot-style). Contact struct uses canonical fields; support both for backwards compatibility.
  defp contact_display_name(contact) when is_map(contact) do
    cond do
      contact[:display_name] != nil or contact["display_name"] != nil ->
        contact[:display_name] || contact["display_name"]

      (contact[:first_name] || contact["first_name"]) != nil or
          (contact[:last_name] || contact["last_name"]) != nil ->
        first = contact[:first_name] || contact["first_name"]
        last = contact[:last_name] || contact["last_name"]
        [first, last] |> Enum.reject(&is_nil/1) |> Enum.join(" ") |> String.trim()

      (contact[:firstname] || contact["firstname"]) != nil or
          (contact[:lastname] || contact["lastname"]) != nil ->
        first = contact[:firstname] || contact["firstname"]
        last = contact[:lastname] || contact["lastname"]
        [first, last] |> Enum.reject(&is_nil/1) |> Enum.join(" ") |> String.trim()

      true ->
        contact[:email] || contact["email"] || "Unknown"
    end
  end

  defp contact_email(%Contact{} = contact), do: contact.email || ""

  defp contact_email(contact) when is_map(contact) do
    contact[:email] || contact["email"] || ""
  end

  defp avatar_fallback(assigns) do
    initials =
      assigns.name
      |> String.split(" ")
      |> Enum.map(&String.first/1)
      |> Enum.join()
      |> String.upcase()

    assigns = assign(assigns, :initials, initials)

    ~H"""
    <div class="h-8 w-8 rounded-full bg-muted flex items-center justify-center text-xs font-medium text-muted-foreground flex-shrink-0">
      {@initials}
    </div>
    """
  end

  # ============================================================================
  # EMPTY STATE
  # ============================================================================

  attr :message, :string, required: true
  attr :submessage, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-8">
      <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-muted mb-4">
        <Icon.info class="h-6 w-6 text-muted-foreground" />
      </div>
      <p class="text-sm text-foreground">{@message}</p>
      <p :if={@submessage} class="text-xs text-muted-foreground mt-1">{@submessage}</p>
    </div>
    """
  end

  # ============================================================================
  # SUGGESTION CARD
  # ============================================================================

  attr :suggestion, :map, required: true

  def suggestion_card(assigns) do
    field_name = to_string(assigns.suggestion.field)
    assigns = assign(assigns, :field_name, field_name)

    ~H"""
    <div class="bg-muted rounded-lg p-4">
      <div class="flex items-start justify-between">
        <div class="flex items-start gap-3">
          <input
            type="checkbox"
            checked={@suggestion.apply}
            name={"apply[#{@field_name}]"}
            id={"apply-#{@field_name}"}
            value="on"
            class="h-4 w-4 rounded border-border text-primary focus:ring-primary mt-0.5"
          />
          <input type="hidden" name={"values[#{@field_name}]"} value={@suggestion.new_value} />
          <div>
            <div class="text-sm font-medium text-foreground">{@suggestion.label}</div>
            <div class="mt-2 space-y-2">
              <div class="flex items-center gap-2">
                <span class="text-xs text-muted-foreground line-through">
                  {@suggestion.current_value || "No value"}
                </span>
                <Icon.chevron_right class="h-3 w-3 text-muted-foreground" />
                <span class="text-sm text-foreground font-medium">
                  {@suggestion.new_value}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MODAL FOOTER
  # ============================================================================

  attr :cancel_patch, :string, default: nil
  attr :cancel_click, :any, default: nil
  attr :submit_text, :string, default: "Submit"
  attr :submit_class, :string, default: ""
  attr :loading, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :loading_text, :string, default: "Processing..."
  attr :info_text, :string, default: nil

  def modal_footer(assigns) do
    ~H"""
    <div class="relative pt-5 mt-6 flex items-center justify-between border-t border-border">
      <div :if={@info_text} class="text-xs text-muted-foreground">
        {@info_text}
      </div>
      <div :if={!@info_text}></div>
      <div class="flex gap-3">
        <%= cond do %>
          <% @cancel_patch -> %>
            <.link patch={@cancel_patch}>
              <.button type="button" variant="outline">Cancel</.button>
            </.link>
          <% @cancel_click -> %>
            <.button type="button" variant="outline" phx-click={@cancel_click}>
              Cancel
            </.button>
          <% true -> %>
            <.button type="button" variant="outline">Cancel</.button>
        <% end %>
        <.button type="submit" disabled={@loading || @disabled} class={@submit_class}>
          <%= if @loading do %>
            <Icon.spinner class="w-4 h-4 animate-spin inline-block mr-2" />
            {@loading_text}
          <% else %>
            {@submit_text}
          <% end %>
        </.button>
      </div>
    </div>
    """
  end
end
