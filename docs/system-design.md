# System Design: UI Component System

Social Scribe uses a shadcn/ui-style component library built with Phoenix function components for consistent, themeable UI across the app.

## Entry Point

- **`SocialScribeWeb.UI`** – All LiveViews and templates use `use SocialScribeWeb.UI` to import UI components.

## Components

Components live in `lib/social_scribe_web/components/ui/`:

- Button, Card, Dialog, Form, Alert, Badge, Icon, Switch, Avatar, Skeleton, Tabs, Tooltip, DropdownMenu, Separator, DateTime

Components accept variant and other attributes for consistent styling (e.g. `<.button variant={:primary}>`).

## Theme System

The single source of truth for colors and theming is **`assets/css/app.css`**:

- **Semantic CSS custom properties** – e.g. `--background`, `--foreground`, `--primary`, `--muted`
- **Dark mode** – Applied via the `.dark` class on the root
- **Tailwind** – Components use utilities that reference these via the `@theme` directive (e.g. `bg-background`, `text-primary`, `border-muted`)

## Adding a New Component

1. Create a new module in `lib/social_scribe_web/components/ui/your_component.ex`.
2. Import it in `lib/social_scribe_web/components/ui.ex`.
3. Use semantic Tailwind classes that reference `@theme` variables (e.g. `bg-background`, `text-primary`, `border-muted`) so the component respects light/dark theme.
