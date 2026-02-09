# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Social Scribe is an Elixir/Phoenix LiveView application that transforms meeting transcripts into follow-up emails and social media content using AI. Key integrations include Google Calendar, Recall.ai (meeting transcription), Anthropic/Google Gemini (AI content generation), HubSpot/Salesforce (CRM), and LinkedIn/Facebook (social posting).

## Development Commands

### Setup

```bash
mix setup          # Install deps, create DB, migrate, install assets
mix phx.server     # Start development server (localhost:4000)
iex -S mix phx.server  # Start with interactive shell
```

### Database

```bash
mix ecto.create    # Create database
mix ecto.migrate   # Run migrations
mix ecto.reset     # Drop, recreate, and migrate
```

### Testing

```bash
mix test                           # Run all tests (includes DB setup)
mix test test/path/to_test         # Run specific test file
mix test test/social_scribe/meetings_test.exs:35  # Run specific test line
```

### Assets

```bash
mix tailwind social_scribe      # Build Tailwind CSS (watch mode: mix tailwind social_scribe --watch)
mix esbuild social_scribe       # Build JS assets (watch mode: mix esbuild social_scribe --watch)
mix assets.deploy               # Build and minify for production
```

### Background Jobs (Oban)

- Access Oban dashboard at `/dev/oban` (dev only)
- Three queues configured: `default` (10), `ai_content` (10), `polling` (5)
- Cron jobs in `config/config.exs`:
- `CrmTokenRefresher` every 5 minutes - refreshes OAuth tokens for all CRM providers

## Architecture

### UI Component System

The app uses a shadcn/ui-style component library built with Phoenix function components:

- **Entry point:** `SocialScribeWeb.UI` - imports all UI components via `use SocialScribeWeb.UI`
- **Components:** `lib/social_scribe_web/components/ui/` - Button, Card, Dialog, Form, Alert, Badge, Icon, Switch, Avatar, Skeleton, Tabs, Tooltip, DropdownMenu
- **Theme system:** Semantic CSS custom properties in `assets/css/app.css` - single source of truth for colors, supports dark mode via `.dark` class
  - Uses CSS custom properties like `--background`, `--foreground`, `--primary`, `--muted`, etc.
  - Components use Tailwind utilities that reference these via `@theme` directive (e.g., `bg-background`, `text-primary`)
- **Usage:** Components accept variant attributes (e.g., `<.button variant={:primary}>`) for consistent styling

To add a new UI component:

1. Create module in `lib/social_scribe_web/components/ui/your_component.ex`
2. Import it in `lib/social_scribe_web/components/ui.ex`
3. Use semantic Tailwind classes that reference `@theme` variables (e.g., `bg-background`, `text-primary`, `border-muted`)

### CRM Abstraction Layer

All CRM integrations (HubSpot, Salesforce) share a unified interface:

- `SocialScribe.Crm.Behaviour` - Behaviour defining required callbacks
- `SocialScribe.Crm.Registry` - Maps provider strings to adapter modules
- `SocialScribe.Crm.Adapters.*` - Provider-specific implementations
- `SocialScribe.Workers.CrmTokenRefresher` - Single unified token refresher for all CRMs

To add a new CRM:

1. Create adapter in `lib/social_scribe/crm/adapters/your_crm.ex` implementing `Crm.Behaviour`
2. Add to `Crm.Registry` providers map
3. Create Ueberauth strategy in `lib/ueberauth/strategy/`
4. Add OAuth provider configuration to `config/config.exs`

### LLM Abstraction

AI calls use a provider-agnostic interface:

- `SocialScribe.LLM.Provider` - Behaviour with single `complete/1` callback
- `SocialScribe.LLM.Anthropic` (default) / `SocialScribe.LLM.Gemini` - Implementations
- `SocialScribe.AIContentGenerator` - Constructs prompts, delegates to LLM.Provider
  - Implements `AIContentGeneratorApi` behaviour for testability

Switch providers by configuring `:llm_provider` in `config/runtime.exs`:

```elixir
config :social_scribe, :llm_provider, SocialScribe.LLM.Anthropic
# or
config :social_scribe, :llm_provider, SocialScribe.LLM.Gemini
```

### Key Data Flow

1. User toggles "Record Meeting" on calendar event → `RecallBot` created
2. Cron job (`BotStatusPoller`) checks bot status every 2 minutes (or webhooks handle real-time updates)
3. When bot completes → transcript saved → `AIContentGenerationWorker` enqueued to `ai_content` queue
4. AI generates follow-up email + processes all user automations
5. Results stored in `Meeting`, `AutomationResult` tables

### Code Organization

The codebase follows a modular structure:

- **Contexts**: Business logic organized by domain (e.g., `Meetings`, `Accounts`, `Automations`)
- **Sub-modules**: Large contexts are split into focused sub-modules:
  - `Meetings.Crm` - CRM auto-detection logic
  - `Meetings.PromptBuilder` - AI prompt generation
  - `Meetings.ParticipantParser` - Participant data parsing
  - `Meetings.TranscriptFormatter` - Transcript formatting
- **Components**: UI components split by functionality:
  - `ChatPopup.MessageList` - Message rendering
  - `ChatPopup.MentionHandler` - Mention handling logic
- **Utilities**: Shared utilities:
  - `AIContentGenerator.JsonParser` - JSON parsing with multiple strategies
  - `ErrorHandler` - Common error formatting and handling

### LiveView Architecture

- Main dashboard: `HomeLive` - shows upcoming calendar events
- Meeting details: `MeetingLive.Show` - transcripts, AI content, CRM modal
- Settings: `UserSettingsLive` - OAuth connections, bot preferences
- CRM chat: `CrmChatLive` - ask questions about CRM contacts with @mentions

### Authentication

- Ueberauth for all OAuth providers (Google, LinkedIn, Facebook, HubSpot, Salesforce)
- Credentials stored in `UserCredential` table with auto-refresh support
- Custom strategies in `lib/ueberauth/strategy/` for HubSpot and Salesforce
- Google OAuth uses `access_type: offline` and `prompt: consent` to get refresh tokens
- Salesforce Connected App OAuth scopes must be set to: `api`, `refresh_token`, `openid` only

## Environment Configuration

Required environment variables (source via `.envrc` or set manually):

- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` / `GOOGLE_REDIRECT_URI` - Google Calendar OAuth
- `RECALL_API_KEY` / `RECALL_REGION` - Recall.ai meeting transcription
- `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_MODEL` - Anthropic API (default LLM)
- `GEMINI_API_KEY` / `GEMINI_MODEL` - Google Gemini (alternative LLM)
- `HUBSPOT_CLIENT_ID` / `HUBSPOT_CLIENT_SECRET` - HubSpot OAuth (optional)
- `SALESFORCE_CLIENT_ID` / `SALESFORCE_CLIENT_SECRET` - Salesforce OAuth (optional)
- `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET` - LinkedIn posting (optional)
- `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` - Facebook posting (optional)

## Testing Patterns

- Use Mox for external API mocking
- Test helpers in `test/support/fixtures/`
- Property tests exist for some modules (`*_property_test.exs`)
- CRM tests use generic `CrmApiMock` for unified testing

## Key Contexts/Schemas

- `SocialScribe.Accounts` - User management, credentials
- `SocialScribe.Calendar` / `CalendarEvent` - Google Calendar sync
- `SocialScribe.Bots` / `RecallBot` - Meeting bot lifecycle
- `SocialScribe.Meetings` / `Meeting` - Transcript storage, AI content
- `SocialScribe.Automations` / `Automation` - User-defined content templates
- `SocialScribe.Crm` - CRM integration modules
