defmodule SocialScribeWeb.UI.Button do
  @moduledoc """
  Button component with shadcn/ui style variants.

  ## Examples

      <.button>Default Button</.button>
      <.button variant="primary">Primary</.button>
      <.button variant="secondary">Secondary</.button>
      <.button variant="outline">Outline</.button>
      <.button variant="ghost">Ghost</.button>
      <.button variant="destructive">Destructive</.button>

      <.button size="sm">Small</.button>
      <.button size="md">Medium</.button>
      <.button size="lg">Large</.button>
      <.button size="icon">Icon Only</.button>

      <.button disabled>Disabled</.button>
      <.button loading>Loading...</.button>
  """
  use Phoenix.Component

  alias SocialScribeWeb.UI.Icon
  alias Phoenix.LiveView.JS

  @variants [
    "default",
    "primary",
    "secondary",
    "outline",
    "ghost",
    "destructive",
    "link"
  ]

  @sizes ["default", "xs", "sm", "lg", "icon"]

  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :variant, :string, values: @variants, default: "default"
  attr :size, :string, values: @sizes, default: "default"
  attr :disabled, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled or @loading}
      class={[
        button_base_classes(),
        variant_classes(@variant),
        size_classes(@size),
        @loading && "cursor-wait",
        @class
      ]}
      {@rest}
    >
      <%= if @loading do %>
        <Icon.spinner class="w-4 h-4 mr-2 animate-spin" />
      <% end %>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_base_classes do
    "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-all duration-200 ease-in-out focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 cursor-pointer active:scale-95 hover:brightness-110"
  end

  defp variant_classes("default") do
    "bg-primary text-primary-foreground hover:bg-primary/90"
  end

  defp variant_classes("primary") do
    "bg-primary text-primary-foreground hover:bg-primary/90"
  end

  defp variant_classes("secondary") do
    "bg-secondary text-secondary-foreground hover:bg-secondary/80"
  end

  defp variant_classes("outline") do
    "border border-border bg-background hover:bg-accent hover:text-accent-foreground"
  end

  defp variant_classes("ghost") do
    "hover:bg-accent hover:text-accent-foreground"
  end

  defp variant_classes("destructive") do
    "bg-destructive text-destructive-foreground hover:bg-destructive/90"
  end

  defp variant_classes("link") do
    "text-primary underline-offset-4 hover:underline"
  end

  defp size_classes("default") do
    "h-10 px-4 py-2"
  end

  defp size_classes("xs") do
    "h-8 rounded-md px-2"
  end

  defp size_classes("sm") do
    "h-9 rounded-md px-3"
  end

  defp size_classes("lg") do
    "h-11 rounded-md px-8"
  end

  defp size_classes("icon") do
    "h-10 w-10"
  end

  # ============================================================================
  # ICON BUTTON
  # ============================================================================

  @doc """
  Icon-only button component.

  ## Examples

      <.icon_button>
        <UI.Icon name="hero-plus" class="w-4 h-4" />
      </.icon_button>

      <.icon_button variant="outline" size="sm">
        <UI.Icon name="hero-trash" class="w-4 h-4" />
      </.icon_button>
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :variant, :string, values: @variants, default: "default"
  attr :size, :string, values: ["default", "xs", "sm", "lg"], default: "default"
  attr :disabled, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def icon_button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled or @loading}
      class={[
        button_base_classes(),
        variant_classes(@variant),
        icon_size_classes(@size),
        @loading && "cursor-wait",
        @class
      ]}
      {@rest}
    >
      <%= if @loading do %>
        <Icon.spinner class="w-4 h-4 animate-spin" />
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </button>
    """
  end

  defp icon_size_classes("default"), do: "h-10 w-10"
  defp icon_size_classes("sm"), do: "h-9 w-9"
  defp icon_size_classes("lg"), do: "h-11 w-11"
  defp icon_size_classes("xs"), do: "h-8 w-8"
  defp icon_size_classes("icon"), do: "h-10 w-10"
end
