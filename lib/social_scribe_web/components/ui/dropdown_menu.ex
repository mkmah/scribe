defmodule SocialScribeWeb.UI.DropdownMenu do
  @moduledoc """
  Dropdown menu component for actions and navigation.

  ## Examples

      <.dropdown_menu>
        <.dropdown_menu_trigger>
          <.button variant="outline">Open Menu</.button>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content>
          <.dropdown_menu_item>
            <UI.Icon.user class="mr-2 h-4 w-4" />
            Profile
          </.dropdown_menu_item>
          <.dropdown_menu_item>
            <UI.Icon.settings class="mr-2 h-4 w-4" />
            Settings
          </.dropdown_menu_item>
          <.dropdown_menu_separator />
          <.dropdown_menu_item variant="destructive">
            <UI.Icon.logout class="mr-2 h-4 w-4" />
            Logout
          </.dropdown_menu_item>
        </.dropdown_menu_content>
      </.dropdown_menu>
      
      <.dropdown_menu align="end">
        <.dropdown_menu_trigger as_child>
          <.avatar src="/avatar.jpg" fallback="JD" />
        </.dropdown_menu_trigger>
        <.dropdown_menu_content>
          <.dropdown_menu_label>My Account</.dropdown_menu_label>
          <.dropdown_menu_separator />
          <.dropdown_menu_group>
            <.dropdown_menu_item>Profile</.dropdown_menu_item>
            <.dropdown_menu_item>Billing</.dropdown_menu_item>
          </.dropdown_menu_group>
        </.dropdown_menu_content>
      </.dropdown_menu>
  """
  use Phoenix.Component

  alias SocialScribeWeb.UI.Icon
  alias Phoenix.LiveView.JS

  # ============================================================================
  # DROPDOWN MENU CONTAINER
  # ============================================================================

  attr :id, :string, default: nil
  attr :align, :string, values: ["start", "center", "end"], default: "center"
  attr :side, :string, values: ["top", "bottom"], default: "bottom"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def dropdown_menu(assigns) do
    id = assigns.id || "dropdown-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :id, id)

    ~H"""
    <div
      id={@id}
      class={["relative inline-block text-left", @class]}
      phx-click-away={hide_menu(@id)}
      {@rest}
    >
      {render_slot(@inner_block, id: @id)}
    </div>
    """
  end

  # ============================================================================
  # DROPDOWN MENU TRIGGER
  # ============================================================================

  attr :dropdown_id, :string, default: nil, doc: "The dropdown id to toggle"
  attr :as_child, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  # When as_child=true, wrap the child in a transparent div with the click handler
  def dropdown_menu_trigger(%{as_child: true} = assigns) do
    ~H"""
    <div phx-click={toggle_menu(@dropdown_id)} class={["inline-flex", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  def dropdown_menu_trigger(assigns) do
    ~H"""
    <button type="button" phx-click={toggle_menu(@dropdown_id)} class={[@class]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  # ============================================================================
  # DROPDOWN MENU CONTENT
  # ============================================================================

  attr :align, :string, values: ["start", "center", "end"], default: "center"
  attr :side, :string, values: ["top", "bottom"], default: "bottom"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def dropdown_menu_content(assigns) do
    ~H"""
    <div
      data-dropdown-content
      class={[
        "absolute z-50 min-w-[8rem] overflow-hidden rounded-md border border-border bg-popover p-1 text-popover-foreground shadow-md",
        "data-[state=open]:animate-in data-[state=closed]:animate-out",
        "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
        "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
        "data-[state=closed]:slide-out-to-bottom-2 data-[state=open]:slide-in-from-top-2",
        position_classes(@align, @side),
        "hidden",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp position_classes("start", "bottom"), do: "left-0 top-full mt-1 origin-top-left"

  defp position_classes("center", "bottom"),
    do: "left-1/2 top-full mt-1 -translate-x-1/2 origin-top"

  defp position_classes("end", "bottom"), do: "right-0 top-full mt-1 origin-top-right"
  defp position_classes("start", "top"), do: "left-0 bottom-full mb-1 origin-bottom-left"

  defp position_classes("center", "top"),
    do: "left-1/2 bottom-full mb-1 -translate-x-1/2 origin-bottom"

  defp position_classes("end", "top"), do: "right-0 bottom-full mb-1 origin-bottom-right"

  # ============================================================================
  # DROPDOWN MENU ITEM
  # ============================================================================

  attr :variant, :string, values: ["default", "destructive"], default: "default"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def dropdown_menu_item(assigns) do
    ~H"""
    <button
      type="button"
      disabled={@disabled}
      data-variant={@variant}
      class={[
        "relative flex cursor-pointer select-none items-center gap-1.5 rounded-md px-1.5 py-1 text-sm outline-none transition-colors",
        # Negative margins to extend hover to container edges
        "-mx-1",
        # Default hover and focus styles
        "hover:bg-accent hover:text-accent-foreground",
        "focus:bg-accent focus:text-accent-foreground",
        # Disabled styles
        "data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
        # Destructive variant - always red text
        "data-[variant=destructive]:text-destructive",
        # Destructive variant - light red bg on hover/focus
        "data-[variant=destructive]:hover:bg-destructive/10",
        "data-[variant=destructive]:hover:text-destructive",
        "data-[variant=destructive]:focus:bg-destructive/10",
        "data-[variant=destructive]:focus:text-destructive",
        # Dark mode for destructive - use more vibrant color
        "dark:data-[variant=destructive]:hover:bg-red-950/50",
        "dark:data-[variant=destructive]:focus:bg-red-950/50",
        "dark:data-[variant=destructive]:text-red-400",
        # Icon styling
        "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # ============================================================================
  # DROPDOWN MENU LABEL
  # ============================================================================

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def dropdown_menu_label(assigns) do
    ~H"""
    <div class={["px-2 py-1.5 text-sm font-semibold", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # DROPDOWN MENU SEPARATOR
  # ============================================================================

  attr :class, :string, default: nil

  def dropdown_menu_separator(assigns) do
    ~H"""
    <div class={["-mx-1 my-1 h-px bg-muted", @class]} />
    """
  end

  # ============================================================================
  # DROPDOWN MENU GROUP
  # ============================================================================

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def dropdown_menu_group(assigns) do
    ~H"""
    <div class={["py-1", @class]} role="group">
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # JS COMMANDS
  # ============================================================================

  defp toggle_menu(js \\ %JS{}, id) do
    js
    |> JS.toggle(to: "##{id} [data-dropdown-content]")
  end

  defp hide_menu(js \\ %JS{}, id) do
    js
    |> JS.hide(to: "##{id} [data-dropdown-content]")
  end
end
