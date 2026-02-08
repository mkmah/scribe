defmodule SocialScribeWeb.Theme.ThemeToggle do
  @moduledoc """
  Theme toggle component for switching between light, dark, and system modes.

  ## Examples

      <.theme_toggle />
      <.theme_toggle class="ml-auto" />
  """
  use Phoenix.Component

  import SocialScribeWeb.UI.Icon

  alias Phoenix.LiveView.JS

  attr :id, :string, default: "theme-toggle"
  attr :class, :string, default: nil
  attr :rest, :global

  def theme_toggle(assigns) do
    ~H"""
    <div id={@id} class={["relative", @class]} phx-hook="ThemeToggle" {@rest}>
      <.dropdown_menu align="end">
        <.dropdown_menu_trigger as_child>
          <.icon_button variant="ghost" size="icon">
            <.sun class="h-[1.2rem] w-[1.2rem] rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
            <.moon class="absolute h-[1.2rem] w-[1.2rem] rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
            <span class="sr-only">Toggle theme</span>
          </.icon_button>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content align="end">
          <.dropdown_menu_item data-theme-option="light">
            <.sun class="mr-2 h-4 w-4" /> Light
            <.check class={["ml-auto h-4 w-4", "hidden"]} data-theme-indicator="light" />
          </.dropdown_menu_item>
          <.dropdown_menu_item data-theme-option="dark">
            <.moon class="mr-2 h-4 w-4" /> Dark
            <.check class={["ml-auto h-4 w-4", "hidden"]} data-theme-indicator="dark" />
          </.dropdown_menu_item>
          <.dropdown_menu_item data-theme-option="system">
            <.monitor class="mr-2 h-4 w-4" /> System
            <.check class={["ml-auto h-4 w-4", "hidden"]} data-theme-indicator="system" />
          </.dropdown_menu_item>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </div>
    """
  end

  defp dropdown_menu(assigns) do
    ~H"""
    <div class="relative inline-block text-left" phx-click-away={hide_dropdown()}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp dropdown_menu_trigger(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={toggle_dropdown()}
      class="inline-flex items-center justify-center"
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp dropdown_menu_content(assigns) do
    assigns = assign_new(assigns, :class, fn -> nil end)

    ~H"""
    <div class={[
      "absolute z-50 min-w-[8rem] overflow-hidden rounded-md border border-border bg-popover p-1 text-popover-foreground shadow-md hidden",
      "right-0 top-full mt-1 origin-top-right",
      @align == "end" && "right-0",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp dropdown_menu_item(assigns) do
    rest = Map.drop(assigns, [:__changed__, :inner_block])
    assigns = assign(assigns, :rest, rest)

    ~H"""
    <button
      type="button"
      class="relative flex w-full cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none transition-colors hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp icon_button(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:rest, fn -> %{} end)

    ~H"""
    <button
      type="button"
      class={[
        "inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors",
        "hover:bg-accent hover:text-accent-foreground",
        "h-10 w-10",
        @variant == "ghost" && "hover:bg-accent hover:text-accent-foreground",
        @size == "icon" && "h-10 w-10",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp toggle_dropdown(js \\ %JS{}) do
    js
    |> JS.toggle(to: ".dropdown-content")
  end

  defp hide_dropdown(js \\ %JS{}) do
    js
    |> JS.hide(to: ".dropdown-content")
  end
end
