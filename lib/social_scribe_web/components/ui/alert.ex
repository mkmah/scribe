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
  attr :kind, :atom, values: [:info, :error, :success, :warning, :danger], required: true
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
  Renders flash messages as toasts: fixed position (default top-right), with close button and auto-dismiss timeout.
  """
  attr :flash, :map, required: true
  attr :duration, :integer, default: 5000
  attr :id, :string, default: nil
  attr :flash_timestamp, :integer, default: nil

  attr :position, :string,
    default: "top-right",
    values: [
      "top",
      "bottom",
      "left",
      "right",
      "top-right",
      "top-left",
      "bottom-right",
      "bottom-left"
    ]

  def flash_toast(assigns) do
    # Read flash messages - Phoenix.Flash.get() consumes them, but that's OK
    # The key is to ensure each flash creates a unique DOM element
    # Use flash_timestamp if available to ensure uniqueness across updates
    base_timestamp = assigns[:flash_timestamp] || System.system_time(:millisecond)

    entries =
      for kind <- [:info, :error, :success, :warning, :danger],
          message = Phoenix.Flash.get(assigns.flash, kind),
          message != nil do
        # Create a unique ID using flash_timestamp + random number
        # The flash_timestamp ensures each new flash gets a different ID
        random = :rand.uniform(1_000_000)
        unique_id = "toast-#{kind}-#{base_timestamp}-#{random}"
        {kind, message, unique_id}
      end

    # Debug: Log when entries are created
    require Logger

    Logger.debug(
      "FlashToast: Flash map keys: #{inspect(Map.keys(assigns.flash))}, Entries: #{length(entries)}, Flash timestamp: #{base_timestamp}"
    )

    if length(entries) > 0 do
      Logger.debug("FlashToast: Entry details: #{inspect(entries)}")
    end

    # Generate unique ID if not provided (prevents duplicate ID warnings in tests)
    # Use socket ID if available (for LiveView), otherwise generate a unique ID
    container_id =
      cond do
        assigns[:id] -> assigns[:id]
        socket = assigns[:socket] -> "flash-toast-container-#{socket.id}"
        true -> "flash-toast-container-#{System.unique_integer([:positive, :monotonic])}"
      end

    assigns =
      assigns
      |> assign(:entries, entries)
      |> assign(:container_id, container_id)
      |> assign(:position_classes, position_classes(assigns.position))
      |> assign(:slide_animation, slide_animation_class(assigns.position))
      |> assign(:flash_timestamp, base_timestamp)

    ~H"""
    <div
      id={@container_id}
      data-flash-timestamp={@flash_timestamp}
      class={[
        "fixed z-50 flex flex-col gap-2 pointer-events-none [&>*]:pointer-events-auto",
        @position_classes
      ]}
      role="region"
      aria-label="Notifications"
    >
      <div
        :for={{kind, message, unique_id} <- @entries}
        id={unique_id}
        phx-hook="FlashToast"
        data-duration={@duration}
        data-toast-id={unique_id}
        role="alert"
        class={[
          "flex items-start gap-3 w-full max-w-sm rounded-lg border border-border p-4 shadow-lg bg-card",
          "animate-in fade-in-0 duration-300",
          @slide_animation,
          flash_variant_classes(kind)
        ]}
      >
        <.flash_icon kind={kind} />
        <p class="flex-1 text-sm font-medium min-w-0">{message}</p>
        <button
          type="button"
          phx-click={JS.hide(to: "##{unique_id}")}
          class="shrink-0 rounded-md p-1 opacity-70 hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring"
          aria-label="Close"
        >
          <Icon.x class="h-4 w-4" />
        </button>
      </div>
    </div>
    """
  end

  defp position_classes("top"), do: "top-4 left-1/2 -translate-x-1/2"
  defp position_classes("bottom"), do: "bottom-4 left-1/2 -translate-x-1/2"
  defp position_classes("left"), do: "left-4 top-1/2 -translate-y-1/2"
  defp position_classes("right"), do: "right-4 top-1/2 -translate-y-1/2"
  defp position_classes("top-right"), do: "top-4 right-4"
  defp position_classes("top-left"), do: "top-4 left-4"
  defp position_classes("bottom-right"), do: "bottom-4 right-4"
  defp position_classes("bottom-left"), do: "bottom-4 left-4"

  defp slide_animation_class("top"), do: "slide-in-from-top-4"
  defp slide_animation_class("top-right"), do: "slide-in-from-top-4"
  defp slide_animation_class("top-left"), do: "slide-in-from-top-4"
  defp slide_animation_class("bottom"), do: "slide-in-from-bottom-4"
  defp slide_animation_class("bottom-right"), do: "slide-in-from-bottom-4"
  defp slide_animation_class("bottom-left"), do: "slide-in-from-bottom-4"
  defp slide_animation_class("left"), do: "slide-in-from-left-4"
  defp slide_animation_class("right"), do: "slide-in-from-right-4"

  defp flash_variant_classes(:info), do: "border-info/50 text-info"

  defp flash_variant_classes(:error),
    do: "border-destructive/50 text-destructive"

  defp flash_variant_classes(:danger),
    do: "border-destructive/50 text-destructive"

  defp flash_variant_classes(:success), do: "border-success/50 text-success"
  defp flash_variant_classes(:warning), do: "border-warning/50 text-warning"

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

  defp flash_icon(%{kind: :danger} = assigns) do
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
