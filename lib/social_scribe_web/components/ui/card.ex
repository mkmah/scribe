defmodule SocialScribeWeb.UI.Card do
  @moduledoc """
  Card component with header, content, and footer slots.

  ## Examples

      <.card>
        <:header>
          <.card_title>Card Title</.card_title>
          <.card_description>Card description goes here</.card_description>
        </:header>
        <.card_content>
          <p>Main content of the card</p>
        </.card_content>
        <:footer>
          <.button>Action</.button>
        </:footer>
      </.card>

      <.card class="w-[350px]">
        <.card_header>
          <.card_title>Simple Card</.card_title>
        </.card_header>
        <.card_content>
          <p>Card content</p>
        </.card_content>
      </.card>
  """
  use Phoenix.Component

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true
  slot :header
  slot :footer

  def card(assigns) do
    ~H"""
    <div
      class={[
        "rounded-lg border border-border bg-card text-card-foreground shadow-sm",
        @class
      ]}
      {@rest}
    >
      <%= if @header != [] do %>
        <div class="flex flex-col space-y-1.5 p-6">
          {render_slot(@header)}
        </div>
      <% end %>

      {render_slot(@inner_block)}

      <%= if @footer != [] do %>
        <div class="flex items-center p-6 pt-0">
          {render_slot(@footer)}
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # CARD HEADER
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card_header(assigns) do
    ~H"""
    <div class={["flex flex-col space-y-1.5 p-6", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # CARD TITLE
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card_title(assigns) do
    ~H"""
    <h3 class={["text-xl font-semibold leading-none tracking-tight", @class]} {@rest}>
      {render_slot(@inner_block)}
    </h3>
    """
  end

  # ============================================================================
  # CARD DESCRIPTION
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card_description(assigns) do
    ~H"""
    <p class={["text-sm text-muted-foreground", @class]} {@rest}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ============================================================================
  # CARD CONTENT
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card_content(assigns) do
    ~H"""
    <div class={["p-6 pt-0", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ============================================================================
  # CARD FOOTER
  # ============================================================================

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card_footer(assigns) do
    ~H"""
    <div class={["flex items-center p-6 pt-0", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
