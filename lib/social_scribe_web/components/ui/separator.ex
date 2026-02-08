defmodule SocialScribeWeb.UI.Separator do
  @moduledoc """
  Separator component.

  ## Examples

      <.separator orientation="horizontal" />
      <.separator orientation="vertical" />
  """
  use Phoenix.Component

  attr :orientation, :string, values: ["horizontal", "vertical"], default: "horizontal"
  attr :decorative, :boolean, default: true

  def separator(assigns) do
    ~H"""
    <div class={orientation_classes(@orientation)} />
    """
  end

  defp orientation_classes("horizontal") do
    "w-full h-[1px] bg-border"
  end

  defp orientation_classes("vertical") do
    "h-full w-[1px] bg-border"
  end
end
