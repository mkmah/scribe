defmodule SocialScribeWeb.Layout.Sidebar do
  @moduledoc """
  Sidebar navigation component.
  """
  use Phoenix.Component

  alias SocialScribeWeb.UI.Icon

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false

  slot :inner_block, required: true

  def sidebar_link(assigns) do
    ~H"""
    <.link
      href={@href}
      class={[
        "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
        "hover:bg-accent hover:text-accent-foreground",
        @active && "bg-primary text-primary-foreground",
        !@active && "text-muted-foreground"
      ]}
    >
      <Icon.icon name={@icon} class="h-4 w-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def get_initials(email) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.split(".")
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  def get_initials(_), do: "??"
end
