defmodule SocialScribeWeb.ClipboardButtonComponent do
  use SocialScribeWeb, :live_component

  def render(assigns) do
    ~H"""
    <button
      id={@id}
      phx-hook="Clipboard"
      phx-target={@myself}
      type="button"
      phx-click="copy"
      phx-value-text={@text}
      class="inline-flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-[#232323] border border-gray-200 dark:border-[#2e2e2e] rounded-md hover:bg-gray-50 dark:hover:bg-[#2a2a2a] focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-[#1c1c1c] focus:ring-brand-500 transition-colors duration-150"
    >
      <div class="relative size-4 mb-2">
        <.icon
          name="hero-clipboard"
          class={"absolute inset-0 transition-all duration-300 #{if(@copied_text, do: "opacity-0 scale-90", else: "opacity-100 scale-100")}"}
        />
        <.icon
          name="hero-check"
          class={"absolute inset-0 transition-all duration-300 #{if(@copied_text, do: "opacity-100 scale-100", else: "opacity-0 scale-90")}"}
        />
      </div>
      <span class="transition-opacity duration-300">
        {if @copied_text, do: "Copied!", else: "Copy"}
      </span>
    </button>
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
