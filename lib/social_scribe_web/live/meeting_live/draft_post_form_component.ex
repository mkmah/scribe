defmodule SocialScribeWeb.MeetingLive.DraftPostFormComponent do
  use SocialScribeWeb, :live_component

  import SocialScribeWeb.ClipboardButton

  alias SocialScribe.Poster

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-semibold">Draft Post</h3>
        <p class="text-sm text-muted-foreground">
          Generate a post based on insights from this meeting.
        </p>
      </div>

      <.form
        for={@form}
        id="draft-post-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="post"
        class="space-y-4"
      >
        <.form_field>
          <.textarea
            field={@form[:generated_content]}
            value={@automation_result.generated_content}
            rows={6}
          />
        </.form_field>

        <div class="flex items-center justify-between pt-4">
          <.clipboard_button id="draft-post-button" text={@form[:generated_content].value} />

          <div class="flex items-center gap-2">
            <.button
              type="button"
              variant="outline"
              phx-click={Phoenix.LiveView.JS.patch(~p"/dashboard/meetings/#{@meeting}")}
            >
              Cancel
            </.button>
            <.button type="submit" phx-disable-with="Posting...">Post</.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(
        form: to_form(%{"generated_content" => assigns.automation_result.generated_content})
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, form: to_form(params))}
  end

  @impl true
  def handle_event("post", %{"generated_content" => generated_content}, socket) do
    case Poster.post_on_social_media(
           socket.assigns.automation.platform,
           generated_content,
           socket.assigns.current_user
         ) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Post successful")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, error)
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}
    end
  end
end
