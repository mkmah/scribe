defmodule SocialScribeWeb.UI.Tabs do
  @moduledoc """
  Tabs component for organizing content.

  ## Examples

      <.tabs default="account" id="settings-tabs">
        <:list>
          <.tabs_trigger value="account" tabs_id="settings-tabs">
            Account
          </.tabs_trigger>
          <.tabs_trigger value="password" tabs_id="settings-tabs">
            Password
          </.tabs_trigger>
        </:list>
        <:content value="account">
          <p>Account settings content</p>
        </:content>
        <:content value="password">
          <p>Password settings content</p>
        </:content>
      </.tabs>
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # ============================================================================
  # TABS CONTAINER
  # ============================================================================

  attr :id, :string, required: true
  attr :default, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  slot :list, required: true
  slot :content, required: true

  def tabs(assigns) do
    default_tab = assigns.default || List.first(assigns.content)[:value]
    assigns = assign(assigns, :default_tab, default_tab)

    ~H"""
    <div
      id={@id}
      class={["w-full", @class]}
      data-default-tab={@default_tab}
      phx-mounted={show_tab(@id, @default_tab)}
      {@rest}
    >
      <div class="relative">
        {render_slot(@list, tabs_id: @id)}
      </div>
      <%= for tab <- @content do %>
        <div id={"#{@id}-content-#{tab.value}"} class="hidden mt-2" data-tab-content={tab.value}>
          {render_slot(tab)}
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # TABS LIST
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def tabs_list(assigns) do
    ~H"""
    <div
      role="tablist"
      class={[
        "inline-flex h-10 items-center justify-center rounded-md bg-muted p-1 text-muted-foreground",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # TABS TRIGGER
  # ============================================================================

  attr :value, :string, required: true
  attr :tabs_id, :string, required: true
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def tabs_trigger(assigns) do
    ~H"""
    <button
      type="button"
      role="tab"
      data-tab-trigger={@value}
      disabled={@disabled}
      phx-click={switch_tab(@tabs_id, @value)}
      class={[
        "inline-flex items-center justify-center whitespace-nowrap rounded-sm px-3 py-1.5 text-sm font-medium",
        "ring-offset-background transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        "disabled:pointer-events-none disabled:opacity-50",
        "data-[state=active]:bg-background data-[state=active]:text-foreground data-[state=active]:shadow-sm",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # ============================================================================
  # TABS CONTENT
  # ============================================================================

  attr :value, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def tabs_content(assigns) do
    ~H"""
    <div
      role="tabpanel"
      data-tab-content={@value}
      class={[
        "mt-2 ring-offset-background",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # JS COMMANDS
  # ============================================================================

  defp show_tab(js \\ %JS{}, tabs_id, value) do
    js
    |> JS.set_attribute({"data-state", "active"}, to: "##{tabs_id} [data-tab-trigger='#{value}']")
    |> JS.show(to: "##{tabs_id}-content-#{value}")
  end

  defp switch_tab(js \\ %JS{}, tabs_id, value) do
    js
    # Hide all content
    |> JS.hide(to: "##{tabs_id} [data-tab-content]")
    # Remove active state from all triggers
    |> JS.remove_attribute("data-state", to: "##{tabs_id} [data-tab-trigger]")
    # Show selected content
    |> JS.show(to: "##{tabs_id}-content-#{value}")
    # Set active state on selected trigger
    |> JS.set_attribute({"data-state", "active"}, to: "##{tabs_id} [data-tab-trigger='#{value}']")
  end
end
