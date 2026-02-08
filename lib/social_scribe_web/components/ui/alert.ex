defmodule SocialScribeWeb.UI.Alert do
  @moduledoc """
  Alert component for notifications and messages.

  ## Examples

      <.alert>
        <.alert_title>Heads up!</.alert_title>
        <.alert_description>You can add components to your app.</.alert_description>
      </.alert>
      
      <.alert variant="destructive">
        <UI.Icon.circle_alert class="h-4 w-4" />
        <.alert_title>Error</.alert_title>
        <.alert_description>Something went wrong.</.alert_description>
      </.alert>
  """
  use Phoenix.Component

  alias SocialScribeWeb.UI.Icon
  alias Phoenix.LiveView.JS

  @variants ["default", "destructive", "success", "warning", "info"]

  attr :variant, :string, values: @variants, default: "default"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div
      role="alert"
      class={[
        "relative w-full rounded-lg border border-border p-4",
        "[&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4 [&>svg]:text-foreground",
        "[&>svg~*]:pl-7",
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
    "bg-background text-foreground"
  end

  defp variant_classes("destructive") do
    "border-destructive/50 text-destructive dark:border-destructive [&>svg]:text-destructive"
  end

  defp variant_classes("success") do
    "border-success/50 text-success dark:border-success [&>svg]:text-success bg-success/10"
  end

  defp variant_classes("warning") do
    "border-warning/50 text-warning dark:border-warning [&>svg]:text-warning bg-warning/10"
  end

  defp variant_classes("info") do
    "border-info/50 text-info dark:border-info [&>svg]:text-info bg-info/10"
  end

  # ============================================================================
  # ALERT TITLE
  # ============================================================================

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def alert_title(assigns) do
    ~H"""
    <h5 class={["mb-1 font-medium leading-none tracking-tight", @class]}>
      {render_slot(@inner_block)}
    </h5>
    """
  end

  # ============================================================================
  # ALERT DESCRIPTION
  # ============================================================================

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def alert_description(assigns) do
    ~H"""
    <div class={["text-sm [&_p]:leading-relaxed", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # TOAST NOTIFICATIONS
  # ============================================================================

  @doc """
  Toast notification component positioned fixed on screen.
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :variant, :string, values: @variants, default: "default"
  attr :show, :boolean, default: false
  attr :duration, :integer, default: 5000

  slot :inner_block

  def toast(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_toast(@id, @duration)}
      class={[
        "fixed bottom-4 right-4 z-50 w-full max-w-sm overflow-hidden rounded-lg border border-border p-4 shadow-lg",
        "data-[state=open]:animate-in data-[state=closed]:animate-out",
        "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
        "data-[state=closed]:slide-out-to-bottom-full data-[state=open]:slide-in-from-bottom-full",
        variant_classes(@variant),
        "hidden"
      ]}
    >
      <%= if @title do %>
        <h5 class="mb-1 font-medium leading-none tracking-tight">{@title}</h5>
      <% end %>
      <%= if @inner_block != [] do %>
        <div class="text-sm [&_p]:leading-relaxed">
          {render_slot(@inner_block)}
        </div>
      <% end %>
    </div>
    """
  end

  defp show_toast(js \\ %JS{}, id, duration) do
    js
    |> JS.show(to: "##{id}")
    |> JS.transition("data-[state=open]", to: "##{id}")
    |> JS.dispatch("toast:show", to: "##{id}", detail: %{duration: duration})
  end

  # ============================================================================
  # FLASH MESSAGES
  # ============================================================================

  @doc """
  Flash message component that integrates with Phoenix flash system.
  """
  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error, :success, :warning], required: true
  attr :class, :string, default: nil

  def flash(assigns) do
    ~H"""
    <%= if message = Phoenix.Flash.get(@flash, @kind) do %>
      <div
        role="alert"
        class={[
          "relative w-full rounded-lg border border-border p-4 mb-4",
          flash_variant_classes(@kind)
        ]}
      >
        <div class="flex items-start gap-3">
          <.flash_icon kind={@kind} />
          <div class="flex-1">
            <p class="text-sm font-medium">{message}</p>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders flash messages as toasts: fixed bottom-right, with close button and auto-dismiss timeout.
  """
  attr :flash, :map, required: true
  attr :duration, :integer, default: 5000

  def flash_toast(assigns) do
    entries =
      for kind <- [:info, :error, :success, :warning],
          message = Phoenix.Flash.get(assigns.flash, kind),
          message != nil,
          do: {kind, message}

    assigns = assign(assigns, :entries, entries)

    ~H"""
    <div
      id="flash-toast-container"
      class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 pointer-events-none [&>*]:pointer-events-auto"
      role="region"
      aria-label="Notifications"
    >
      <div
        :for={{kind, message} <- @entries}
        id={"toast-flash-#{kind}"}
        phx-hook="FlashToast"
        data-duration={@duration}
        role="alert"
        class={[
          "flex items-start gap-3 w-full max-w-sm rounded-lg border border-border p-4 shadow-lg",
          "animate-in fade-in-0 slide-in-from-bottom-4 duration-300",
          flash_variant_classes(kind)
        ]}
      >
        <.flash_icon kind={kind} />
        <p class="flex-1 text-sm font-medium min-w-0">{message}</p>
        <button
          type="button"
          phx-click={JS.hide(to: "#toast-flash-#{kind}")}
          class="shrink-0 rounded-md p-1 opacity-70 hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring"
          aria-label="Close"
        >
          <Icon.x class="h-4 w-4" />
        </button>
      </div>
    </div>
    """
  end

  defp flash_variant_classes(:info), do: "border-info/50 text-info bg-info/10"

  defp flash_variant_classes(:error),
    do: "border-destructive/50 text-destructive bg-destructive/10"

  defp flash_variant_classes(:success), do: "border-success/50 text-success bg-success/10"
  defp flash_variant_classes(:warning), do: "border-warning/50 text-warning bg-warning/10"

  defp flash_icon(%{kind: :info} = assigns) do
    ~H"""
    <Icon.info class="h-5 w-5 text-info mt-0.5" />
    """
  end

  defp flash_icon(%{kind: :error} = assigns) do
    ~H"""
    <Icon.circle_alert class="h-5 w-5 text-destructive mt-0.5" />
    """
  end

  defp flash_icon(%{kind: :success} = assigns) do
    ~H"""
    <Icon.circle_check class="h-5 w-5 text-success mt-0.5" />
    """
  end

  defp flash_icon(%{kind: :warning} = assigns) do
    ~H"""
    <Icon.triangle_alert class="h-5 w-5 text-warning mt-0.5" />
    """
  end
end
