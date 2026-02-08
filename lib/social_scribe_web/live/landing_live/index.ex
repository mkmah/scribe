defmodule SocialScribeWeb.LandingLive.Index do
  use SocialScribeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-[80vh] flex items-center justify-center px-4">
      <div class="max-w-2xl mx-auto text-center">
        <div class="mb-8">
          <.badge variant="primary">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3.5 w-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z"
              />
            </svg>
            AI-Powered Meeting Intelligence
          </.badge>
        </div>

        <h1 class="text-4xl sm:text-5xl md:text-6xl font-semibold text-content-primary tracking-tight leading-[1.1] mb-6">
          Turn meetings into
          <span class="text-primary-600">
            actionable content
          </span>
        </h1>

        <p class="text-lg text-content-tertiary mb-10 max-w-lg mx-auto leading-relaxed">
          Automatically transcribe meetings, generate follow-up emails, and craft social media posts. Save hours every week.
        </p>

        <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
          <.link
            href={~p"/auth/google"}
            class="inline-flex items-center gap-2.5 px-6 py-3 text-base font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 transition-all duration-150 shadow-elevated hover:shadow-elevated hover:-translate-y-0.5"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 533.5 544.3" class="h-5 w-5">
              <path
                d="M533.5 278.4c0-18.5-1.5-37.1-4.7-55.3H272.1v104.8h147c-6.1 33.8-25.7 63.7-54.4 82.7v68h87.7c51.5-47.4 81.1-117.4 81.1-200.2z"
                fill="#fff"
                opacity=".7"
              />
              <path
                d="M272.1 544.3c73.4 0 135.3-24.1 180.4-65.7l-87.7-68c-24.4 16.6-55.9 26-92.6 26-71 0-131.2-47.9-152.8-112.3H28.9v70.1c46.2 91.9 140.3 149.9 243.2 149.9z"
                fill="#fff"
                opacity=".8"
              />
              <path
                d="M119.3 324.3c-11.4-33.8-11.4-70.4 0-104.2V150H28.9c-38.6 76.9-38.6 167.5 0 244.4l90.4-70.1z"
                fill="#fff"
                opacity=".6"
              />
              <path
                d="M272.1 107.7c38.8-.6 76.3 14 104.4 40.8l77.7-77.7C405 24.6 339.7-.8 272.1 0 169.2 0 75.1 58 28.9 150l90.4 70.1c21.5-64.5 81.8-112.4 152.8-112.4z"
                fill="#fff"
                opacity=".9"
              />
            </svg>
            Get Started with Google
          </.link>
        </div>

        <p class="mt-6 text-sm text-content-muted">
          Free to start. Connect your Google Calendar to begin.
        </p>
      </div>
    </div>
    """
  end
end
