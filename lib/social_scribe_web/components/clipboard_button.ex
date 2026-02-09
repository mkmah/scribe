defmodule SocialScribeWeb.ClipboardButtonComponent do
  use SocialScribeWeb, :live_component

  def render(assigns) do
    ~H"""
    <div>
      <.button
        id={@id}
        phx-hook="Clipboard"
        phx-target={@myself}
        phx-click="copy"
        phx-value-text={@text}
        variant="outline"
        size="sm"
        class="h-8 text-xs"
      >
        <span class="relative size-4 mr-1.5">
          <.icon
            name="hero-clipboard"
            class={"absolute inset-0 transition-all duration-300 size-4 #{if(@copied_text, do: "opacity-0 scale-90", else: "opacity-100 scale-100")}"}
          />
          <.icon
            name="hero-check"
            class={"absolute inset-0 transition-all duration-300 size-4 #{if(@copied_text, do: "opacity-100 scale-100", else: "opacity-0 scale-90")}"}
          />
        </span>
        <span class="transition-opacity duration-300">
          {if @copied_text, do: "Copied!", else: "Copy"}
        </span>
      </.button>
    </div>
    """
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:copied_text, fn -> false end)

    {:ok, socket}
  end

  def handle_event("copy", %{"text" => text}, socket) do
    socket =
      socket
      |> push_event("copy-to-clipboard", %{text: text})

    {:noreply, socket}
  end

  def handle_event("copied-to-clipboard", %{"text" => text}, socket) do
    {:noreply, assign(socket, :copied_text, text)}
  end

  def handle_event("reset-copied", _params, socket) do
    {:noreply, assign(socket, :copied_text, false)}
  end
end

defmodule SocialScribeWeb.ClipboardButton do
  use SocialScribeWeb, :html

  attr :id, :string, required: true
  attr :text, :string, required: true

  def clipboard_button(assigns) do
    ~H"""
    <.live_component module={SocialScribeWeb.ClipboardButtonComponent} id={@id} text={@text} />
    """
  end
end
