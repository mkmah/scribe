defmodule SocialScribeWeb.UI.Avatar do
  @moduledoc """
  Avatar component with fallback initials.

  ## Examples

      <.avatar src="/images/user.jpg" alt="John Doe" />
      <.avatar fallback="JD" />
      <.avatar src="/images/user.jpg" fallback="JD" size="lg" />
  """
  use Phoenix.Component

  alias SocialScribeWeb.UI.Icon

  @sizes %{
    "xs" => "h-6 w-6 text-[10px]",
    "sm" => "h-8 w-8 text-xs",
    "default" => "h-10 w-10 text-sm",
    "lg" => "h-12 w-12 text-base",
    "xl" => "h-14 w-14 text-lg"
  }

  attr :src, :string, default: nil
  attr :alt, :string, default: nil
  attr :fallback, :string, default: nil
  attr :size, :string, values: Map.keys(@sizes), default: "default"
  attr :class, :string, default: nil
  attr :rest, :global

  def avatar(assigns) do
    assigns = assign(assigns, :size_class, @sizes[assigns.size])

    ~H"""
    <div
      class={[
        "relative flex shrink-0 overflow-hidden rounded-full",
        @size_class,
        @class
      ]}
      {@rest}
    >
      <%= if @src do %>
        <img
          src={@src}
          alt={@alt}
          class="aspect-square h-full w-full object-cover"
          onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
        />
      <% end %>
      <div class={[
        "flex h-full w-full items-center justify-center rounded-full bg-muted",
        if(@src, do: "hidden")
      ]}>
        <%= if @fallback do %>
          <span class="font-medium text-muted-foreground">
            {@fallback}
          </span>
        <% else %>
          <Icon.user class="h-1/2 w-1/2 text-muted-foreground" />
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # AVATAR GROUP
  # ============================================================================

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def avatar_group(assigns) do
    ~H"""
    <div class={["flex -space-x-2 overflow-hidden", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
