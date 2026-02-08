defmodule SocialScribeWeb.UI.Badge do
  @moduledoc """
  Badge component for status indicators and labels.

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="secondary">Secondary</.badge>
      <.badge variant="outline">Outline</.badge>
      <.badge variant="destructive">Error</.badge>
      <.badge variant="success">Success</.badge>
  """
  use Phoenix.Component

  @variants [
    "default",
    "primary",
    "secondary",
    "outline",
    "destructive",
    "success",
    "warning",
    "info"
  ]

  attr :variant, :string, values: @variants, default: "default"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <div
      class={[
        "inline-flex items-center rounded-full border border-border px-2.5 py-0.5 text-xs font-semibold transition-colors",
        "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
        variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp variant_classes("default") do
    "border-transparent bg-primary text-primary-foreground hover:bg-primary/80"
  end

  defp variant_classes("primary") do
    "border-transparent bg-primary text-primary-foreground hover:bg-primary/80"
  end

  defp variant_classes(:primary) do
    "border-transparent bg-primary text-primary-foreground hover:bg-primary/80"
  end

  defp variant_classes("secondary") do
    "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80"
  end

  defp variant_classes("outline") do
    "text-foreground"
  end

  defp variant_classes("destructive") do
    "border-transparent bg-destructive text-destructive-foreground hover:bg-destructive/80"
  end

  defp variant_classes("success") do
    "border-transparent bg-success text-success-foreground hover:bg-success/80"
  end

  defp variant_classes("warning") do
    "border-transparent bg-warning text-warning-foreground hover:bg-warning/80"
  end

  defp variant_classes("info") do
    "border-transparent bg-info text-info-foreground hover:bg-info/80"
  end

  # ============================================================================
  # STATUS BADGE
  # ============================================================================

  @doc """
  Status badge with dot indicator for active/inactive states.
  """
  attr :status, :string,
    values: ["active", "inactive", "pending", "error", "success"],
    required: true

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def status_badge(assigns) do
    ~H"""
    <div class={[
      "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium",
      status_classes(@status),
      @class
    ]}>
      <span class={["h-1.5 w-1.5 rounded-full", dot_color(@status)]}></span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp status_classes("active"), do: "bg-success/10 text-success"
  defp status_classes("inactive"), do: "bg-muted text-muted-foreground"
  defp status_classes("pending"), do: "bg-warning/10 text-warning"
  defp status_classes("error"), do: "bg-destructive/10 text-destructive"
  defp status_classes("success"), do: "bg-success/10 text-success"

  defp dot_color("active"), do: "bg-success"
  defp dot_color("inactive"), do: "bg-muted-foreground"
  defp dot_color("pending"), do: "bg-warning"
  defp dot_color("error"), do: "bg-destructive"
  defp dot_color("success"), do: "bg-success"
end
