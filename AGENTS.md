# AGENTS.md

Guidelines for AI coding agents working on the Social Scribe Elixir/Phoenix application.

## Build/Lint/Test Commands

### Development

- `mix setup` - Install deps, create DB, migrate, install assets
- `mix phx.server` - Start development server (localhost:4000)
- `iex -S mix phx.server` - Start with interactive shell

### Database

- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run migrations
- `mix ecto.reset` - Drop, recreate, and migrate

### Testing

- `mix test` - Run all tests
- `mix test test/path/to_test.exs` - Run single test file
- `mix test test/path/to_test.exs:123` - Run test at specific line

### Assets

- `mix tailwind social_scribe` - Build Tailwind CSS
- `mix esbuild social_scribe` - Build JS assets

### Formatting

- `mix format` - Format all Elixir files (uses .formatter.exs)
- Formats `*.{heex,ex,exs}`, `{config,lib,test}/**/*.{heex,ex,exs}`

## Code Style Guidelines

### Imports & Aliases

- Group imports: 1) Elixir/Phoenix core, 2) Dependencies, 3) Project aliases
- Use `import` sparingly; prefer `alias` for clarity
- Always use `warn: false` for Ecto imports: `import Ecto.Query, warn: false`
- Example order:

  ```elixir
  import Ecto.Query, warn: false
  alias SocialScribe.Repo
  alias SocialScribe.Accounts.{User, UserCredential}
  ```

### Naming Conventions

- **Modules**: PascalCase, prefix with `SocialScribe.` or `SocialScribeWeb.`
- **Functions**: snake_case, descriptive verbs (`get_user!`, `register_user`)
- **Private functions**: snake_case with `defp`
- **Schema fields**: snake_case atoms
- **Behaviours**: Define callbacks with typespecs

### Error Handling

- Use `{:ok, result}` / `{:error, reason}` tuples consistently
- Raise exceptions only for truly exceptional cases (use `!` suffix)
- Pattern match errors explicitly rather than using `case` chains
- Changeset errors: use `errors_on(changeset)` helper in tests

### Types & Specs

- Define types in schemas and behaviours
- Use `@callback` and `@spec` for public functions
- Prefer explicit types over `any()`:

  ```elixir
  @type contact :: map()
  @callback search_contacts(credential :: UserCredential.t(), query :: String.t()) ::
              {:ok, list(contact())} | {:error, any()}
  ```

### Contexts (Business Logic)

- Place in `lib/social_scribe/*.ex` (plural, e.g., `accounts.ex`)
- Group related operations in a single context module
- Keep contexts decoupled; use explicit aliases between them

### Schemas

- Place in `lib/social_scribe/{context}/{schema}.ex`
- Always use `timestamps(type: :utc_datetime)`
- Mark sensitive fields with `redact: true`
- Define changesets with proper validations

### LiveView

- Use `Phoenix.LiveView` for interactive features
- Mount function pattern: `def mount(_params, _session, socket)`
- Handle events with clear naming: `handle_event("save", params, socket)`
- Prefer function components over render functions

### Testing

- Unit tests: `use SocialScribe.DataCase`
- Controller/LiveView tests: `use SocialScribeWeb.ConnCase`
- Use fixtures from `test/support/fixtures/`
- Mock external APIs with Mox (defined in test_helper.exs)
- Tag integration tests: `@tag :google_auth`

### Behaviours & Adapters

- Define behaviour in `{domain}/behaviour.ex`
- Place adapters in `{domain}/adapters/{provider}.ex`
- Implement all callbacks with consistent return types
- Use Registry pattern for provider lookup

### Configuration

- Environment-specific config in `config/{env}.exs`
- Application config for defaults in `config/config.exs`
- Prefer runtime config for secrets (`config/runtime.exs`)
