defmodule SocialScribeWeb.ModalComponents do
  @moduledoc """
  Reusable UI components for modals and dialogs.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import SocialScribeWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a searchable contact select box.
  """
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
      <label for={"#{@id}-input"} class="block text-sm font-medium text-gray-700 dark:text-gray-300">Select Contact</label>
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
            class="relative w-full bg-white dark:bg-[#232323] border border-gray-200 dark:border-[#2e2e2e] rounded-xl pl-2 pr-10 py-2 text-left cursor-pointer hover:border-gray-300 dark:hover:border-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 text-sm transition-colors"
          >
            <span class="flex items-center">
              <.avatar firstname={@selected_contact.firstname} lastname={@selected_contact.lastname} size={:sm} />
              <span class="ml-2 block truncate text-gray-900 dark:text-gray-100">
                {@selected_contact.firstname} {@selected_contact.lastname}
              </span>
            </span>
            <span class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <.icon name="hero-chevron-up-down" class="h-4 w-4 text-gray-400" />
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
              class="w-full bg-white dark:bg-[#232323] border border-gray-200 dark:border-[#2e2e2e] rounded-xl pl-3 pr-10 py-2 text-sm text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-colors"
            />
            <span class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <%= if @loading do %>
                <.icon name="hero-arrow-path" class="h-4 w-4 text-gray-400 animate-spin" />
              <% else %>
                <.icon name="hero-chevron-up-down" class="h-4 w-4 text-gray-400" />
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
          class="absolute z-10 mt-1.5 w-full bg-white dark:bg-[#232323] shadow-lg max-h-60 rounded-xl py-1 text-sm ring-1 ring-gray-200 dark:ring-[#2e2e2e] overflow-auto"
        >
          <button
            :if={@selected_contact}
            type="button"
            phx-click="clear_contact"
            phx-target={@target}
            role="option"
            aria-selected={"false"}
            class="w-full text-left px-4 py-2 hover:bg-gray-50 dark:hover:bg-[#2a2a2a] text-sm text-gray-500 dark:text-gray-400 cursor-pointer transition-colors"
          >
            Clear selection
          </button>
          <div :if={@loading} class="px-4 py-2 text-sm text-gray-400 dark:text-gray-500">
            Searching...
          </div>
          <div :if={!@loading && Enum.empty?(@contacts) && @query != ""} class="px-4 py-2 text-sm text-gray-400 dark:text-gray-500">
            No contacts found
          </div>
          <button
            :for={contact <- @contacts}
            type="button"
            phx-click="select_contact"
            phx-value-id={contact.id}
            phx-target={@target}
            role="option"
            aria-selected={"false"}
            class="w-full text-left px-4 py-2.5 hover:bg-gray-50 dark:hover:bg-[#2a2a2a] flex items-center gap-3 cursor-pointer transition-colors"
          >
            <.avatar firstname={contact.firstname} lastname={contact.lastname} size={:sm} />
            <div>
              <div class="text-sm font-medium text-gray-900 dark:text-gray-100">
                {contact.firstname} {contact.lastname}
              </div>
              <div class="text-xs text-gray-400 dark:text-gray-500">
                {contact.email}
              </div>
            </div>
          </button>
        </div>
      </div>
      <.inline_error :if={@error} message={@error} />
    </div>
    """
  end

  @doc """
  Renders a search input with icon.
  """
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search..."
  attr :loading, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def search_input(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
        <.icon name="hero-magnifying-glass" class="h-4 w-4 text-gray-400" />
      </div>
      <input
        type="text"
        name={@name}
        value={@value}
        class="block w-full pl-10 pr-3 py-2 border border-gray-200 dark:border-[#2e2e2e] bg-white dark:bg-[#232323] rounded-xl text-sm text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-colors"
        placeholder={@placeholder}
        {@rest}
      />
      <div :if={@loading} class="absolute inset-y-0 right-0 pr-3 flex items-center">
        <.icon name="hero-arrow-path" class="h-4 w-4 text-gray-400 animate-spin" />
      </div>
    </div>
    """
  end

  @doc """
  Renders an avatar with initials.
  """
  attr :firstname, :string, default: ""
  attr :lastname, :string, default: ""
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: nil

  def avatar(assigns) do
    size_classes = %{
      sm: "h-7 w-7 text-[10px]",
      md: "h-8 w-8 text-[11px]",
      lg: "h-10 w-10 text-sm"
    }

    assigns = assign(assigns, :size_class, size_classes[assigns.size])

    ~H"""
    <div class={[
      "rounded-full bg-gray-100 dark:bg-[#2e2e2e] flex items-center justify-center font-semibold text-gray-500 dark:text-gray-400 flex-shrink-0",
      @size_class,
      @class
    ]}>
      {String.at(@firstname || "", 0)}{String.at(@lastname || "", 0)}
    </div>
    """
  end

  @doc """
  Renders a clickable contact list item.
  """
  attr :contact, :map, required: true
  attr :on_click, :string, required: true
  attr :target, :any, default: nil
  attr :class, :string, default: nil

  def contact_list_item(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_click}
      phx-value-id={@contact.id}
      phx-target={@target}
      class={[
        "w-full px-4 py-3 text-left hover:bg-gray-50 dark:hover:bg-[#2a2a2a] transition-colors flex items-center gap-3",
        @class
      ]}
    >
      <.avatar firstname={@contact.firstname} lastname={@contact.lastname} size={:md} />
      <div>
        <div class="text-sm font-medium text-gray-900 dark:text-gray-100">
          {@contact.firstname} {@contact.lastname}
        </div>
        <div class="text-xs text-gray-400 dark:text-gray-500">
          {@contact.email}
          <span :if={@contact[:company]} class="text-gray-300 dark:text-gray-600">- {@contact.company}</span>
        </div>
      </div>
    </button>
    """
  end

  @doc """
  Renders a contact list container.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def contact_list(assigns) do
    ~H"""
    <div class={[
      "border border-gray-200 dark:border-[#2e2e2e] rounded-xl divide-y divide-gray-100 dark:divide-gray-700 max-h-64 overflow-y-auto bg-white dark:bg-[#232323]",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a value comparison (old -> new).
  """
  attr :current_value, :string, default: nil
  attr :new_value, :string, required: true
  attr :class, :string, default: nil

  def value_comparison(assigns) do
    ~H"""
    <div class={["flex items-center gap-4", @class]}>
      <div class="flex-1">
        <input
          type="text"
          readonly
          value={@current_value || ""}
          placeholder="No existing value"
          class={[
            "block w-full text-sm bg-white dark:bg-[#232323] border border-gray-200 dark:border-[#2e2e2e] rounded-lg py-2 px-3",
            if(@current_value && @current_value != "", do: "line-through text-gray-400 dark:text-gray-500", else: "text-gray-300 dark:text-gray-600")
          ]}
        />
      </div>
      <div class="text-gray-300 dark:text-gray-600 flex-shrink-0">
        <.icon name="hero-arrow-long-right" class="h-5 w-5" />
      </div>
      <div class="flex-1">
        <input
          type="text"
          readonly
          value={@new_value}
          class="block w-full text-sm text-gray-900 dark:text-gray-100 bg-white dark:bg-[#232323] border border-gray-200 dark:border-[#2e2e2e] rounded-lg py-2 px-3"
        />
      </div>
    </div>
    """
  end

  @doc """
  Renders a suggestion card with checkbox.
  """
  attr :suggestion, :map, required: true
  attr :class, :string, default: nil

  def suggestion_card(assigns) do
    ~H"""
    <div class={["bg-gray-50 dark:bg-[#232323]/50 rounded-2xl p-5 mb-3", @class]}>
      <div class="flex items-start justify-between">
        <div class="flex items-start gap-3">
          <div class="flex items-center h-5 pt-0.5">
            <input
              type="checkbox"
              checked={@suggestion.apply}
              phx-click={JS.dispatch("click", to: "#suggestion-apply-#{@suggestion.field}")}
              class="h-4 w-4 rounded border-gray-300 dark:border-[#2e2e2e] text-brand-600 focus:ring-brand-500 focus:ring-offset-0 dark:bg-[#2e2e2e] cursor-pointer transition-colors"
            />
          </div>
          <div class="text-sm font-medium text-gray-900 dark:text-gray-100">{@suggestion.label}</div>
        </div>

        <div class="flex items-center gap-3">
          <span
            class={[
              "inline-flex items-center rounded-full bg-gray-200/60 dark:bg-[#2e2e2e] px-2.5 py-1 text-xs font-medium text-gray-600 dark:text-gray-400 transition-opacity",
              if(@suggestion.apply, do: "opacity-100", else: "opacity-0 pointer-events-none")
            ]}
          >
            1 update selected
          </span>
          <button type="button" class="text-xs text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 font-medium transition-colors">
            Hide details
          </button>
        </div>
      </div>

      <div class="mt-3 pl-7">
        <div class="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">{@suggestion.label}</div>

        <div class="relative">
          <input
            id={"suggestion-apply-#{@suggestion.field}"}
            type="checkbox"
            name={"apply[#{@suggestion.field}]"}
            value="1"
            checked={@suggestion.apply}
            class="absolute -left-7 top-1/2 -translate-y-1/2 h-4 w-4 rounded border-gray-300 dark:border-[#2e2e2e] text-brand-600 focus:ring-brand-500 focus:ring-offset-0 dark:bg-[#2e2e2e] cursor-pointer transition-colors"
          />

          <div class="grid grid-cols-[1fr_28px_1fr] items-center gap-4">
            <input
              type="text"
              readonly
              value={@suggestion.current_value || ""}
              placeholder="No existing value"
              class={[
                "block w-full text-sm bg-white dark:bg-[#232323] border border-gray-200 dark:border-[#2e2e2e] rounded-lg py-2 px-3",
                if(@suggestion.current_value && @suggestion.current_value != "", do: "line-through text-gray-400 dark:text-gray-500", else: "text-gray-300 dark:text-gray-600")
              ]}
            />

            <div class="flex justify-center text-gray-300 dark:text-gray-600">
              <.icon name="hero-arrow-long-right" class="h-5 w-5" />
            </div>

            <input
              type="text"
              name={"values[#{@suggestion.field}]"}
              value={@suggestion.new_value}
              class="block w-full text-sm text-gray-900 dark:text-gray-100 bg-white dark:bg-[#232323] border border-gray-200 dark:border-[#2e2e2e] rounded-lg py-2 px-3 focus:ring-brand-500 focus:border-brand-500 transition-colors"
            />
          </div>
        </div>

        <div class="mt-2.5 grid grid-cols-[1fr_28px_1fr] items-start gap-4">
          <button type="button" class="text-xs text-brand-600 dark:text-brand-400 hover:text-brand-700 dark:hover:text-brand-300 font-medium justify-self-start transition-colors">
            Update mapping
          </button>
          <span></span>
          <span :if={@suggestion[:timestamp]} class="text-xs text-gray-400 dark:text-gray-500 justify-self-start">
            Found in transcript
            <span class="text-brand-600 dark:text-brand-400 hover:underline cursor-help" title={@suggestion[:context]}>
              ({@suggestion[:timestamp]})
            </span>
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a success message with checkmark icon.
  """
  attr :title, :string, required: true
  attr :message, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block
  slot :actions

  def success_message(assigns) do
    ~H"""
    <div class={["text-center py-8", @class]}>
      <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-emerald-50 dark:bg-emerald-900/30 mb-4">
        <.icon name="hero-check" class="h-6 w-6 text-emerald-500 dark:text-emerald-400" />
      </div>
      <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">{@title}</h3>
      <p :if={@message} class="text-sm text-gray-500 dark:text-gray-400 mb-6">{@message}</p>
      <div :if={@inner_block != []} class="text-sm text-gray-500 dark:text-gray-400 mb-6">
        {render_slot(@inner_block)}
      </div>
      <div :if={@actions != []}>
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a modal footer with cancel and submit buttons.
  """
  attr :cancel_patch, :string, default: nil
  attr :cancel_click, :any, default: nil
  attr :submit_text, :string, default: "Submit"
  attr :submit_class, :string, default: "bg-emerald-600 hover:bg-emerald-700"
  attr :loading, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :loading_text, :string, default: "Processing..."
  attr :info_text, :string, default: nil
  attr :class, :string, default: nil

  def modal_footer(assigns) do
    ~H"""
    <div class={["relative pt-5 mt-6 flex items-center justify-between border-t border-gray-100 dark:border-[#2e2e2e]", @class]}>
      <div :if={@info_text} class="text-xs text-gray-400 dark:text-gray-500">
        {@info_text}
      </div>
      <div :if={!@info_text}></div>
      <div class="flex gap-3">
        <button
          :if={@cancel_patch}
          type="button"
          phx-click={Phoenix.LiveView.JS.patch(@cancel_patch)}
          class="px-4 py-2.5 border border-gray-200 dark:border-[#2e2e2e] rounded-lg text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-[#232323] hover:bg-gray-50 dark:hover:bg-[#2a2a2a] transition-colors"
        >
          Cancel
        </button>
        <button
          :if={@cancel_click}
          type="button"
          phx-click={@cancel_click}
          class="px-4 py-2.5 border border-gray-200 dark:border-[#2e2e2e] rounded-lg text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-[#232323] hover:bg-gray-50 dark:hover:bg-[#2a2a2a] transition-colors"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={@loading || @disabled}
          class={[
            "px-4 py-2.5 rounded-lg text-sm font-medium text-white shadow-sm transition-all",
            @submit_class,
            "disabled:opacity-50 disabled:cursor-not-allowed"
          ]}
        >
          <span :if={@loading}>{@loading_text}</span>
          <span :if={!@loading}>{@submit_text}</span>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders an empty state message.
  """
  attr :title, :string, default: nil
  attr :message, :string, required: true
  attr :submessage, :string, default: nil
  attr :class, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class={["text-center py-8", @class]}>
      <p :if={@title} class="font-medium text-gray-600 dark:text-gray-400 mb-1">{@title}</p>
      <p class="text-sm text-gray-400 dark:text-gray-500">{@message}</p>
      <p :if={@submessage} class="text-xs text-gray-400 dark:text-gray-500 mt-2">{@submessage}</p>
    </div>
    """
  end

  @doc """
  Renders an error message.
  """
  attr :message, :string, required: true
  attr :class, :string, default: nil

  def inline_error(assigns) do
    ~H"""
    <p class={["text-red-500 dark:text-red-400 text-sm", @class]}>{@message}</p>
    """
  end

  @doc """
  Renders a HubSpot-styled modal wrapper.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def hubspot_modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-black/40 backdrop-blur-sm fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="relative hidden rounded-2xl bg-white dark:bg-[#232323] px-8 py-6 shadow-xl ring-1 ring-gray-200 dark:ring-[#2e2e2e] transition"
            >
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  defp hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      time: 200,
      transition:
        {"transition-all ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
