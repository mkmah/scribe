---
name: Component test coverage
overview: Add test files under `test/social_scribe_web/components/` for every component in `lib/social_scribe_web/components/` that currently has no tests. Use ConnCase + Phoenix.LiveViewTest; test function components via `render_component/3` and LiveComponents via `live_isolated/3`.
todos: []
isProject: false
---

# Component test coverage plan

## Current state

- **No component-level tests exist.** There is no `test/social_scribe_web/components/` directory. LiveView tests (e.g. [crm_modal_test.exs](test/social_scribe_web/live/crm_modal_test.exs)) use `ConnCase` and `import Phoenix.LiveViewTest` and hit full pages, so some components are exercised only indirectly.
- All components under [lib/social_scribe_web/components/](lib/social_scribe_web/components/) are in scope.

## Components to cover (by file)

| Category    | Module / file                                                                   | Type              | Public API to test                                                             |
| ----------- | ------------------------------------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------ |
| **UI**      | [ui/alert.ex](lib/social_scribe_web/components/ui/alert.ex)                     | Phoenix.Component | `alert`, `alert_title`, `alert_description`, variants; flash helpers if public |
| **UI**      | [ui/avatar.ex](lib/social_scribe_web/components/ui/avatar.ex)                   | Phoenix.Component | avatar with image/fallback/initials                                            |
| **UI**      | [ui/badge.ex](lib/social_scribe_web/components/ui/badge.ex)                     | Phoenix.Component | badge, status_badge, variants                                                  |
| **UI**      | [ui/button.ex](lib/social_scribe_web/components/ui/button.ex)                   | Phoenix.Component | `button`, `icon_button`, variants/sizes, loading, disabled                     |
| **UI**      | [ui/card.ex](lib/social_scribe_web/components/ui/card.ex)                       | Phoenix.Component | card, card_header, card_title, card_description, card_content, card_footer     |
| **UI**      | [ui/dialog.ex](lib/social_scribe_web/components/ui/dialog.ex)                   | Phoenix.Component | dialog, open/close rendering                                                   |
| **UI**      | [ui/dropdown_menu.ex](lib/social_scribe_web/components/ui/dropdown_menu.ex)     | Phoenix.Component | trigger, content, item (render structure)                                      |
| **UI**      | [ui/form.ex](lib/social_scribe_web/components/ui/form.ex)                       | Phoenix.Component | form helpers, inputs, labels, errors                                           |
| **UI**      | [ui/icon.ex](lib/social_scribe_web/components/ui/icon.ex)                       | Phoenix.Component | `icon`, and key named icons (e.g. `check`, `x`, `spinner`)                     |
| **UI**      | [ui/separator.ex](lib/social_scribe_web/components/ui/separator.ex)             | Phoenix.Component | separator (horizontal/vertical)                                                |
| **UI**      | [ui/skeleton.ex](lib/social_scribe_web/components/ui/skeleton.ex)               | Phoenix.Component | skeleton                                                                       |
| **UI**      | [ui/switch.ex](lib/social_scribe_web/components/ui/switch.ex)                   | Phoenix.Component | switch (rendered state)                                                        |
| **UI**      | [ui/tabs.ex](lib/social_scribe_web/components/ui/tabs.ex)                       | Phoenix.Component | tabs list/trigger/content                                                      |
| **UI**      | [ui/tooltip.ex](lib/social_scribe_web/components/ui/tooltip.ex)                 | Phoenix.Component | tooltip wrapper content                                                        |
| **Other**   | [modal_components.ex](lib/social_scribe_web/components/modal_components.ex)     | Phoenix.Component | `contact_select`, `empty_state`, `suggestion_card`, `modal_footer`             |
| **Other**   | [integration_card.ex](lib/social_scribe_web/components/integration_card.ex)     | Phoenix.Component | `integration_card` (name, description, connected, slots)                       |
| **Other**   | [platform_logo.ex](lib/social_scribe_web/components/platform_logo.ex)           | HTML component    | `platform_logo` (google_meet vs zoom by URL)                                   |
| **Other**   | [layout/sidebar.ex](lib/social_scribe_web/components/layout/sidebar.ex)         | Phoenix.Component | `sidebar_link`, `get_initials` (pure function)                                 |
| **Other**   | [theme/theme_toggle.ex](lib/social_scribe_web/components/theme/theme_toggle.ex) | Phoenix.Component | `theme_toggle` (markup and options)                                            |
| **Live**    | [clipboard_button.ex](lib/social_scribe_web/components/clipboard_button.ex)     | LiveComponent     | Renders copy button; optional: `copy` event pushes `copy-to-clipboard`         |
| **Live**    | [chat_popup.ex](lib/social_scribe_web/components/chat_popup.ex)                 | LiveComponent     | Renders when open; events (toggle, close, send_message, etc.) and Chat context |
| **Layouts** | [layouts.ex](lib/social_scribe_web/components/layouts.ex)                       | Layout module     | Optional: minimal “app layout renders” via a live request to an existing route |

Layout templates (`layouts/*.heex`) are not separate test targets; they are exercised via layout embedding and existing live tests.

## Test layout and patterns

- **Directory:** `test/social_scribe_web/components/`.
- **Case:** Use [ConnCase](test/support/conn_case.ex) (same as [crm_modal_test.exs](test/social_scribe_web/live/crm_modal_test.exs)), `async: true` where possible.
- **Imports:** `import Phoenix.LiveViewTest` for `render_component/3` and `live_isolated/3`.

**Function components (Phoenix.Component):**

- Use `render_component({Module, :function}, assigns)` for components without slots.
- For components with required `inner_block`, pass a do-block or function:  
`render_component({Module, :function}, assigns, do: "content")` (or equivalent slot content).
- Assert on output HTML: presence of text, classes, roles, or key elements (e.g. `assert html =~ "Click me"`, `assert html =~ "role=\"alert\""`).

**LiveComponents:**

- Use `live_isolated(conn, Component, assigns)` to mount the component with required assigns (e.g. `current_user`, `id`).
- **ClipboardButtonComponent:** Assigns include `text`, optional `copied_text`; assert initial “Copy” and optional event `push_event("copy-to-clipboard", %{text: ...})` in a test that triggers `copy`.
- **ChatPopup:** Requires `current_user` (and possibly Chat context). Either stub `SocialScribe.Crm.Chat` (e.g. with Mox or test-only behaviour) or use fixtures (user, conversations). Test: mount closed by default; toggle opens; optional send_message/load_conversation with stubbed Chat.

**ModalComponents:**

- `contact_select`: Use a struct or map for `selected_contact` and `contacts` (e.g. `%SocialScribe.Crm.Contact{}` or map with `display_name`/`email`) so `contact_display_name`/`contact_email` work; assert labels, “Clear selection”, “No contacts found” when appropriate.
- `empty_state`, `suggestion_card`, `modal_footer`: Pass minimal assigns and assert message/text and buttons.

**PlatformLogo:**

- Renders via `use SocialScribeWeb, :html`; can be tested by rendering in a minimal LiveView or by calling the component through a test LiveView that uses the same `:html` helpers (so `platform_logo` is available). Alternatively, invoke the component’s render from a test that builds the same assigns (e.g. `recall_bot: %{meeting_url: "https://meet.google.com/..."}`) and assert Google Meet SVG vs Zoom URL.

**Layouts:**

- Optional single test: e.g. `live(conn, existing_dashboard_route)` and assert a distinctive part of the app layout (e.g. nav or footer) to avoid regressions. No need to test every layout variant in isolation.

## Suggested test files

1. `**ui_components_test.exs**` – One describe block per UI module (Alert, Avatar, Badge, Button, Card, Dialog, DropdownMenu, Form, Icon, Separator, Skeleton, Switch, Tabs, Tooltip). Keep each to a few tests: default render, key variants/slots, and one edge case where useful.
2. `**modal_components_test.exs**` – `contact_select` (with and without selected contact, loading, error), `empty_state`, `suggestion_card`, `modal_footer` (cancel_patch vs cancel_click, loading).
3. `**integration_card_test.exs**` – `integration_card` connected vs not, with connection_list and action slots.
4. `**platform_logo_test.exs**` – `platform_logo` for Google Meet URL, Zoom URL, and default.
5. `**sidebar_test.exs**` – `sidebar_link` (active/inactive), `get_initials` (email string and non-binary).
6. `**theme_toggle_test.exs**` – `theme_toggle` renders and contains theme options (Light/Dark/System).
7. `**clipboard_button_test.exs**` – Renders “Copy”; (optional) “copy” event and push_event.
8. `**chat_popup_test.exs**` – Mount closed; open via toggle (with stubbed or fixture Chat); optionally send_message/load_conversation.
9. `**layouts_test.exs**` (optional) – One test that an existing live route renders and the app layout appears.

## Dependencies and fixtures

- **ModalComponents** and **Contact:** Use `%SocialScribe.Crm.Contact{display_name: "...", email: "..."}` or a minimal map with `display_name`/`email` (or `firstname`/`lastname` for map style) so private helpers don’t crash.
- **ChatPopup:** Depends on `SocialScribe.Crm.Chat` (list_conversations, get_conversation!, get_conversation_messages, create_message, etc.). Prefer one of: (a) Mox/behaviour stub for Chat in test, or (b) real DB with [AccountsFixtures](test/support/fixtures/accounts_fixtures.ex) and a small Chat fixture so the component runs against test data.
- **ClipboardButtonComponent:** No DB; only needs `conn` and assigns. JS hook “Clipboard” is not run in ExUnit; testing push_event is sufficient for server-side behavior.

## Out of scope

- Layout **templates** (`app.html.heex`, `dashboard.html.heex`, `root.html.heex`) are not given dedicated unit tests; they are covered by existing live and (if added) layout smoke tests.
- **ui.ex** is only a macro that imports UI components; no need to test it in isolation.
- Deep testing of Tailwind classes or visual regression; tests should only assert structure and key content/attributes.

## Order of implementation

1. Add `test/social_scribe_web/components/` and a single file (e.g. `ui_components_test.exs`) with one or two UI components (e.g. Button, Alert) to lock in the pattern and confirm `render_component` works with `ConnCase`.
2. Complete the rest of the UI components in `ui_components_test.exs`.
3. Add `modal_components_test.exs`, `integration_card_test.exs`, `platform_logo_test.exs`, `sidebar_test.exs`, `theme_toggle_test.exs`.
4. Add `clipboard_button_test.exs`, then `chat_popup_test.exs` (with Chat stubbed or fixtures).
5. Optionally add `layouts_test.exs`.

This keeps the plan proportional and avoids over-testing layout markup while covering all component modules that are not yet tested.
