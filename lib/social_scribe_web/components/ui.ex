defmodule SocialScribeWeb.UI do
  @moduledoc """
  UI component library for SocialScribe.

  This module provides shadcn/ui-style components for building the application interface.
  All components use semantic CSS custom properties defined in app.css for consistent theming.

  ## Available Components

  - **UI.Button** - Button and IconButton components
  - **UI.Card** - Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
  - **UI.Dialog** - Modal/Dialog with overlay
  - **UI.Form** - Form fields, inputs, labels, errors
  - **UI.Alert** - Alerts and flash messages
  - **UI.Badge** - Status badges and labels
  - **UI.Icon** - Icon components and SVG icons
  - **UI.Switch** - Toggle switches
  - **UI.Avatar** - User avatars with fallbacks
  - **UI.Skeleton** - Loading skeleton placeholders
  - **UI.Tabs** - Tab navigation
  - **UI.Tooltip** - Hover tooltips
  - **UI.DropdownMenu** - Dropdown menus

  ## Usage

      use SocialScribeWeb.UI

      # Or import specific components
      import SocialScribeWeb.UI.Button
      import SocialScribeWeb.UI.Card
  """

  defmacro __using__(_opts) do
    quote do
      import SocialScribeWeb.UI.Alert
      import SocialScribeWeb.UI.Avatar
      import SocialScribeWeb.UI.Badge
      import SocialScribeWeb.UI.Button
      import SocialScribeWeb.UI.Card
      import SocialScribeWeb.UI.Dialog
      import SocialScribeWeb.UI.DropdownMenu
      import SocialScribeWeb.UI.Form
      import SocialScribeWeb.UI.Icon
      import SocialScribeWeb.UI.Separator
      import SocialScribeWeb.UI.Skeleton
      import SocialScribeWeb.UI.Switch
      import SocialScribeWeb.UI.Tabs
      import SocialScribeWeb.UI.Tooltip
    end
  end
end
