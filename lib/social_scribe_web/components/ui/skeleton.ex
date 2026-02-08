defmodule SocialScribeWeb.UI.Skeleton do
  @moduledoc """
  Skeleton loading component for placeholders.

  ## Examples

      <.skeleton class="h-4 w-[250px]" />
      <.skeleton class="h-12 w-12 rounded-full" />
      
      <.skeleton_card />
      <.skeleton_text lines={3} />
  """
  use Phoenix.Component

  attr :class, :string, default: nil
  attr :rest, :global

  def skeleton(assigns) do
    ~H"""
    <div
      class={[
        "animate-pulse rounded-md bg-muted",
        @class
      ]}
      {@rest}
    />
    """
  end

  # ============================================================================
  # SKELETON CARD
  # ============================================================================

  attr :class, :string, default: nil

  def skeleton_card(assigns) do
    ~H"""
    <Card.card class={["p-6", @class]}>
      <div class="space-y-3">
        <.skeleton class="h-4 w-1/3" />
        <.skeleton class="h-3 w-full" />
        <.skeleton class="h-3 w-2/3" />
      </div>
    </Card.card>
    """
  end

  # ============================================================================
  # SKELETON TEXT
  # ============================================================================

  attr :lines, :integer, default: 3
  attr :class, :string, default: nil

  def skeleton_text(assigns) do
    ~H"""
    <div class={["space-y-2", @class]}>
      <%= for i <- 1..@lines do %>
        <.skeleton class={["h-4", if(i == @lines, do: "w-2/3", else: "w-full")]} />
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SKELETON TABLE
  # ============================================================================

  attr :rows, :integer, default: 5
  attr :columns, :integer, default: 4
  attr :class, :string, default: nil

  def skeleton_table(assigns) do
    ~H"""
    <div class={["space-y-3", @class]}>
      <%!-- Header --%>
      <div class="flex gap-4">
        <%= for _ <- 1..@columns do %>
          <.skeleton class="h-6 flex-1" />
        <% end %>
      </div>
      <%!-- Rows --%>
      <%= for _ <- 1..@rows do %>
        <div class="flex gap-4">
          <%= for _ <- 1..@columns do %>
            <.skeleton class="h-10 flex-1" />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SKELETON LIST
  # ============================================================================

  attr :items, :integer, default: 5
  attr :class, :string, default: nil

  def skeleton_list(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <%= for _ <- 1..@items do %>
        <div class="flex items-center gap-4">
          <.skeleton class="h-10 w-10 rounded-full" />
          <div class="flex-1 space-y-2">
            <.skeleton class="h-4 w-1/3" />
            <.skeleton class="h-3 w-1/2" />
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
