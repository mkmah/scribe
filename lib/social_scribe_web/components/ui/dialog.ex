defmodule SocialScribeWeb.UI.Dialog do
  @moduledoc """
  Dialog/Modal component with overlay, header, content, and footer.

  ## Examples

      <.dialog id="confirm-modal" show>
        <:header>
          <.dialog_title>Confirm Action</.dialog_title>
          <.dialog_description>Are you sure you want to proceed?</.dialog_description>
        </:header>
        <:content>
          <p>This action cannot be undone.</p>
        </:content>
        <:footer>
          <.button variant="outline" phx-click={hide_modal("confirm-modal")}>Cancel</.button>
          <.button>Confirm</.button>
        </:footer>
      </.dialog>
      
      <.dialog_trigger target="my-modal">
        <.button>Open Dialog</.button>
      </.dialog_trigger>
  """
  use Phoenix.Component

  alias SocialScribeWeb.UI.Icon
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :size, :string, values: ["sm", "md", "lg", "xl", "full"], default: "md"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :header
  slot :content
  slot :footer
  slot :inner_block

  def dialog(assigns) do
    size_classes = %{
      "sm" => "max-w-sm",
      "md" => "max-w-lg",
      "lg" => "max-w-2xl",
      "xl" => "max-w-4xl",
      "full" => "max-w-full"
    }

    assigns = assign(assigns, :size_class, size_classes[assigns.size])

    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
      {@rest}
    >
      <%!-- Backdrop --%>
      <div
        id={"#{@id}-backdrop"}
        class="fixed inset-0 z-50 bg-black/80 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0"
        aria-hidden="true"
      />

      <%!-- Dialog Container --%>
      <div class="fixed inset-0 z-50 grid place-items-center overflow-y-auto p-4" tabindex="-1">
        <.focus_wrap
          id={"#{@id}-container"}
          phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
          phx-key="escape"
          phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
          class={[
            "relative z-50 grid w-full gap-4 border border-border bg-background p-6 shadow-lg duration-200",
            "data-[state=open]:animate-in data-[state=closed]:animate-out",
            "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
            "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
            "data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%]",
            "data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%]",
            "sm:rounded-lg",
            @size_class,
            @class
          ]}
        >
          <%= if @header != [] do %>
            <div class="flex flex-col space-y-1.5 text-center sm:text-left">
              {render_slot(@header)}
            </div>
          <% end %>

          <%= if @content != [] do %>
            <div class="text-sm text-muted-foreground">
              {render_slot(@content)}
            </div>
          <% else %>
            <div class="text-sm text-muted-foreground">
              {render_slot(@inner_block)}
            </div>
          <% end %>

          <%= if @footer != [] do %>
            <div class="flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2">
              {render_slot(@footer)}
            </div>
          <% end %>

          <%!-- Close Button --%>
          <button
            type="button"
            phx-click={JS.exec("data-cancel", to: "##{@id}")}
            class="absolute right-4 top-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none data-[state=open]:bg-accent data-[state=open]:text-muted-foreground"
          >
            <Icon.x class="h-4 w-4" />
            <span class="sr-only">Close</span>
          </button>
        </.focus_wrap>
      </div>
    </div>
    """
  end

  # ============================================================================
  # DIALOG HEADER
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def dialog_header(assigns) do
    ~H"""
    <div class={["flex flex-col space-y-1.5 text-center sm:text-left", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # DIALOG TITLE
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def dialog_title(assigns) do
    ~H"""
    <h2 class={["text-lg font-semibold leading-none tracking-tight", @class]} {@rest}>
      {render_slot(@inner_block)}
    </h2>
    """
  end

  # ============================================================================
  # DIALOG DESCRIPTION
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def dialog_description(assigns) do
    ~H"""
    <p class={["text-sm text-muted-foreground", @class]} {@rest}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ============================================================================
  # DIALOG FOOTER
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def dialog_footer(assigns) do
    ~H"""
    <div class={["flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # DIALOG TRIGGER
  # ============================================================================

  attr :target, :string, required: true
  attr :rest, :global

  slot :inner_block, required: true

  def dialog_trigger(assigns) do
    ~H"""
    <div phx-click={show_modal(@target)} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # JS COMMANDS
  # ============================================================================

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(to: "##{id}-backdrop")
    |> JS.show(
      to: "##{id}-container",
      transition: {
        "transition-all ease-out duration-200",
        "opacity-0 scale-95 translate-y-4",
        "opacity-100 scale-100 translate-y-0"
      }
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}-backdrop",
      transition: {"transition-all ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      transition: {
        "transition-all ease-in duration-150",
        "opacity-100 scale-100 translate-y-0",
        "opacity-0 scale-95 translate-y-4"
      }
    )
    |> JS.hide(to: "##{id}")
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
