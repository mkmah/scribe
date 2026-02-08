defmodule SocialScribeWeb.UI.Switch do
  @moduledoc """
  Switch/Toggle component.

  ## Examples

      <.switch name="notifications" checked={@notifications_enabled} />
      <.switch name="dark_mode" checked={@dark_mode}>
        <:label>Dark Mode</:label>
      </.switch>
  """
  use Phoenix.Component

  attr :name, :string, required: true
  attr :id, :string, default: nil
  attr :checked, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :required, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :label

  def switch(assigns) do
    assigns = assign_new(assigns, :id, fn -> assigns.name end)

    ~H"""
    <label class={[
      "inline-flex items-center gap-3 cursor-pointer",
      @disabled && "cursor-not-allowed opacity-50",
      @class
    ]}>
      <input
        type="checkbox"
        name={@name}
        id={@id}
        checked={@checked}
        disabled={@disabled}
        required={@required}
        class="sr-only peer"
        {@rest}
      />
      <div class={[
        "relative w-9 h-5 rounded-full transition-colors duration-200 ease-in-out",
        "bg-input peer-checked:bg-primary",
        "peer-focus:ring-2 peer-focus:ring-ring peer-focus:ring-offset-2",
        "after:content-[''] after:absolute after:top-[2px] after:left-[2px]",
        "after:bg-background after:border after:border-border after:rounded-full",
        "after:h-4 after:w-4 after:transition-all after:duration-200",
        "peer-checked:after:translate-x-4 peer-checked:after:border-background"
      ]}>
      </div>
      <%= if @label != [] do %>
        <span class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">
          {render_slot(@label)}
        </span>
      <% end %>
    </label>
    """
  end
end
