defmodule SocialScribeWeb.Sidebar do
  use SocialScribeWeb, :html

  attr :base_path, :string, required: true
  attr :current_path, :string, required: true
  attr :links, :list, required: true

  slot :widget

  def sidebar(assigns) do
    ~H"""
    <aside class="hidden md:flex w-52 flex-col bg-white dark:bg-[#1c1c1c] border-r border-gray-200 dark:border-[#2e2e2e] sticky top-12 h-[calc(100vh-3rem)]">
      <nav class="flex-1 px-3 py-5">
        <ul class="space-y-0.5">
          <li :for={{label, icon, path} <- @links}>
            <.sidebar_link
              base_path={@base_path}
              href={path}
              icon={icon}
              label={label}
              current_path={@current_path}
              path={path}
            />
          </li>
        </ul>
      </nav>

      <div :for={widget <- @widget}>
        {render_slot(widget)}
      </div>
    </aside>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :base_path, :string, required: true
  attr :current_path, :string, required: true
  attr :path, :string, required: true

  def sidebar_link(assigns) do
    active =
      if assigns.path == assigns.base_path do
        assigns.current_path == assigns.path
      else
        String.starts_with?(assigns.current_path, assigns.path)
      end

    assigns = assign(assigns, :active, active)

    ~H"""
    <.link
      href={@href}
      class={[
        "flex items-center gap-2.5 px-2.5 py-[7px] text-[13px] font-medium rounded-md transition-all duration-100",
        @active && "bg-brand-500/10 dark:bg-brand-500/15 text-brand-700 dark:text-brand-400",
        !@active && "text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-[#2a2a2a] hover:text-gray-900 dark:hover:text-gray-200"
      ]}
    >
      <.icon
        name={@icon}
        class={
          if @active,
            do: "size-4 flex-shrink-0 text-brand-600 dark:text-brand-400",
            else: "size-4 flex-shrink-0 text-gray-400 dark:text-gray-500"
        }
      />
      {@label}
    </.link>
    """
  end
end
