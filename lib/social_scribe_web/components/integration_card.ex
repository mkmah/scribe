defmodule SocialScribeWeb.Components.IntegrationCard do
  @moduledoc """
  Integration card component for displaying connected services.
  """
  use Phoenix.Component

  import SocialScribeWeb.UI.Card
  import SocialScribeWeb.UI.Badge
  import SocialScribeWeb.UI.Separator

  @icons %{
    google:
      ~S|<svg class="w-5 h-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 533.5 544.3"><path d="M533.5 278.4c0-18.5-1.5-37.1-4.7-55.3H272.1v104.8h147c-6.1 33.8-25.7 63.7-54.4 82.7v68h87.7c51.5-47.4 81.1-117.4 81.1-200.2z" fill="#4285f4"/><path d="M272.1 544.3c73.4 0 135.3-24.1 180.4-65.7l-87.7-68c-24.4 16.6-55.9 26-92.6 26-71 0-131.2-47.9-152.8-112.3H28.9v70.1c46.2 91.9 140.3 149.9 243.2 149.9z" fill="#34a853"/><path d="M119.3 324.3c-11.4-33.8-11.4-70.4 0-104.2V150H28.9c-38.6 76.9-38.6 167.5 0 244.4l90.4-70.1z" fill="#fbbc04"/><path d="M272.1 107.7c38.8-.6 76.3 14 104.4 40.8l77.7-77.7C405 24.6 339.7-.8 272.1 0 169.2 0 75.1 58 28.9 150l90.4 70.1c21.5-64.5 81.8-112.4 152.8-112.4z" fill="#ea4335"/></svg>|,
    hubspot:
      ~S|<svg class="h-5 w-5 text-[#ff7a59]" viewBox="0 0 24 24" fill="currentColor"><path d="M18.164 7.93V5.084a2.198 2.198 0 001.267-1.984v-.066A2.2 2.2 0 0017.231.834h-.066a2.2 2.2 0 00-2.2 2.2v.066c0 .873.517 1.626 1.267 1.984V7.93a6.152 6.152 0 00-3.267 1.643l-6.6-5.133a2.726 2.726 0 00.067-.582A2.726 2.726 0 003.706 1.13a2.726 2.726 0 00-2.726 2.727 2.726 2.726 0 002.726 2.727c.483 0 .938-.126 1.333-.347l6.486 5.047a6.195 6.195 0 00-.556 2.572 6.18 6.18 0 00.56 2.572l-1.57 1.223a2.457 2.457 0 00-1.49-.504 2.468 2.468 0 00-2.468 2.468 2.468 2.468 0 002.468 2.468 2.468 2.468 0 002.468-2.468c0-.29-.05-.568-.142-.826l1.558-1.213a6.2 6.2 0 003.812 1.312 6.2 6.2 0 006.199-6.2 6.2 6.2 0 00-4.2-5.856zm-4.2 9.193a3.337 3.337 0 110-6.674 3.337 3.337 0 010 6.674z"/></svg>|,
    salesforce:
      ~S|<svg class="h-5 w-5 text-[#00a1e0]" viewBox="0 0 24 24" fill="currentColor"><path d="M10.008 3.083c1.063-1.123 2.537-1.82 4.17-1.82 2.138 0 3.97 1.176 4.95 2.917.86-.378 1.8-.588 2.792-.588C24.99 3.592 27.6 6.2 27.6 9.272c0 .38-.039.75-.112 1.108 1.825.85 3.088 2.713 3.088 4.87 0 2.953-2.393 5.346-5.346 5.346H7.44c-3.396 0-6.148-2.753-6.148-6.148 0-2.78 1.845-5.13 4.377-5.894.19-2.417 1.697-4.458 3.839-5.471z" transform="scale(0.73)"/></svg>|,
    facebook:
      ~S|<svg class="h-5 w-5 text-[#1877f2]" viewBox="0 0 32 32" fill="currentColor"><path d="M21.95 5.005l-3.306-.004c-3.206 0-5.277 2.124-5.277 5.415v2.495H10.05v4.515h3.317l-.004 9.575h4.641l.004-9.575h3.806l-.003-4.514h-3.803v-2.117c0-1.018.241-1.533 1.566-1.533l2.366-.001.01-4.256z"/></svg>|,
    linkedin:
      ~S|<svg class="h-5 w-5 text-[#0077b5]" viewBox="0 0 382 382" fill="currentColor"><path d="M347.445,0H34.555C15.471,0,0,15.471,0,34.555v312.889C0,366.529,15.471,382,34.555,382h312.889C366.529,382,382,366.529,382,347.444V34.555C382,15.471,366.529,0,347.445,0z M118.207,329.844c0,5.554-4.502,10.056-10.056,10.056H65.345c-5.554,0-10.056-4.502-10.056-10.056V150.403c0-5.554,4.502-10.056,10.056-10.056h42.806c5.554,0,10.056,4.502,10.056,10.056V329.844z M86.748,123.432c-22.459,0-40.666-18.207-40.666-40.666S64.289,42.1,86.748,42.1s40.666,18.207,40.666,40.666S109.208,123.432,86.748,123.432z M341.91,330.654c0,5.106-4.14,9.246-9.246,9.246H286.73c-5.106,0-9.246-4.14-9.246-9.246v-84.168c0-12.556,3.683-55.021-32.813-55.021c-28.309,0-34.051,29.066-35.204,42.11v97.079c0,5.106-4.139,9.246-9.246,9.246h-44.426c-5.106,0-9.246-4.14-9.246-9.246V149.593c0-5.106,4.14-9.246,9.246-9.246h44.426c5.106,0,9.246,4.14,9.246,9.246v15.655c10.497-15.753,26.097-27.912,59.312-27.912c73.552,0,73.131,68.716,73.131,106.472L341.91,330.654L341.91,330.654z"/></svg>|
  }

  attr :name, :string, required: true
  attr :description, :string, required: true
  attr :connected, :boolean, default: false
  attr :icon, :atom, required: true

  slot :connection_list
  slot :action

  def integration_card(assigns) do
    assigns = assign(assigns, :icon_svg, @icons[assigns.icon])

    ~H"""
    <.card>
      <.card_content class="pt-6">
        <div class="flex items-start justify-between gap-4">
          <div class="flex items-start gap-4">
            <div class="flex items-center justify-center w-10 h-10 border rounded-lg shrink-0 border-border bg-background">
              {Phoenix.HTML.raw(@icon_svg)}
            </div>
            <div class="space-y-1">
              <h3 class="font-semibold leading-none tracking-tight">{@name}</h3>
              <p class="text-sm text-muted-foreground">{@description}</p>
            </div>
          </div>
          <.status_badge status={if @connected, do: "active", else: "inactive"}>
            {if @connected, do: "Connected", else: "Not Connected"}
          </.status_badge>
        </div>

        <%= if @connection_list != [] do %>
          <div class="mt-4 space-y-2">
            {render_slot(@connection_list)}
          </div>
        <% end %>

        <%= if @action != [] do %>
          <div class="pt-2 mt-2">
            <.separator />
          </div>
          <div class="pt-2 mt-2">
            {render_slot(@action)}
          </div>
        <% end %>
      </.card_content>
    </.card>
    """
  end
end
