defmodule SocialScribeWeb.UI.Tooltip do
  @moduledoc """
  Tooltip component for displaying helpful information on hover.

  ## Examples

      <.tooltip>
        <.tooltip_trigger>
          <.button>Hover me</.button>
        </.tooltip_trigger>
        <.tooltip_content>
          This is a tooltip
        </.tooltip_content>
      </.tooltip>

      <.tooltip position="bottom">
        <.tooltip_trigger>
          <UI.Icon.info class="h-4 w-4" />
        </.tooltip_trigger>
        <.tooltip_content>
          More information about this feature
        </.tooltip_content>
      </.tooltip>
  """
  use Phoenix.Component

  @positions ["top", "bottom", "left", "right"]

  attr :position, :string, values: @positions, default: "top"
  attr :delay, :integer, default: 150
  attr :content, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <div
      class={["relative inline-block group", @class]}
      data-tooltip-position={@position}
      data-tooltip-delay={@delay}
      {@rest}
    >
      {render_slot(@inner_block)}
      <%= if @content do %>
        <span class={[
          "absolute z-50 hidden whitespace-nowrap rounded-md bg-foreground px-2 py-1 text-xs text-background opacity-0 transition-opacity group-hover:block group-hover:opacity-100",
          position_classes(@position)
        ]}>
          {@content}
        </span>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # TOOLTIP TRIGGER
  # ============================================================================

  attr :as, :string, default: "div"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def tooltip_trigger(assigns) do
    ~H"""
    <div class={["tooltip-trigger", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # TOOLTIP CONTENT
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def tooltip_content(assigns) do
    ~H"""
    <div
      role="tooltip"
      class={[
        "absolute z-50 hidden whitespace-nowrap rounded-md bg-foreground px-3 py-1.5 text-xs text-background",
        "opacity-0 transition-opacity duration-150",
        "group-hover:block group-hover:opacity-100",
        "peer-hover:block peer-hover:opacity-100",
        "has-[~.tooltip-trigger:hover]:block has-[~.tooltip-trigger:hover]:opacity-100",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # SIMPLE TOOLTIP WRAPPER
  # ============================================================================

  attr :text, :string, required: true
  attr :position, :string, values: @positions, default: "top"
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def simple_tooltip(assigns) do
    ~H"""
    <span class={["group relative inline-block", @class]}>
      {render_slot(@inner_block)}
      <span class={[
        "absolute z-[100] hidden whitespace-nowrap rounded-md bg-foreground px-2 py-1 text-xs text-background opacity-0 transition-opacity group-hover:block group-hover:opacity-100 pointer-events-none",
        position_classes(@position)
      ]}>
        {@text}
      </span>
    </span>
    """
  end

  defp position_classes("top") do
    "bottom-full left-1/2 mb-2 -translate-x-1/2"
  end

  defp position_classes("bottom") do
    "top-full left-1/2 mt-2 -translate-x-1/2"
  end

  defp position_classes("left") do
    "right-full top-1/2 mr-2 -translate-y-1/2"
  end

  defp position_classes("right") do
    "left-full top-1/2 ml-2 -translate-y-1/2"
  end
end
