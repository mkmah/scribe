# Deployment Guide (Fly.io)

## Prerequisites

- A [Fly.io](https://fly.io/) account.
- `flyctl` command-line tool installed (see [Install flyctl](https://fly.io/docs/hands-on/install-flyctl/)).
- Reliable GitHub repository containing the latest code.

## Continuous Deployment (GitHub Actions)

The repo includes a workflow (`.github/workflows/fly-deploy.yml`) that deploys to Fly.io on every push to the `master` branch:

- **Trigger:** Push to `master`
- **Steps:** Checkout, set up `flyctl` via `superfly/flyctl-actions/setup-flyctl`, then run `flyctl deploy --remote-only`
- **Required secret:** In your GitHub repository, add a secret named `FLY_API_TOKEN` with a Fly.io API token (create one at [fly.io/user/tokens](https://fly.io/user/tokens))

The workflow only runs the deploy; it does **not** set application secrets. All environment variables (e.g. `SECRET_KEY_BASE`, `GOOGLE_CLIENT_ID`, etc.) must be configured in Fly.io with `fly secrets set` as described below. Do that once before relying on the first automated deploy.

## Deployment Steps

1. **Login to Fly.io**
    - Run `fly auth login` in your terminal to authenticate.

2. **Initialize App (First Time Only)**
    - If you haven't launched the app yet, run `fly launch`.
    - Since a `fly.toml` file already exists, it will use that configuration.
    - Follow the prompts to set up your app name and region (if not already set in `fly.toml` or overridden).
    - **Database**: If prompted to set up a Postgres database, say **Yes**. This will automatically provision a Fly Postgres database and set the `DATABASE_URL` secret.
    - **Deploy**: You can choose to deploy now or later.

3. **Configure Secrets (Environment Variables)**
    - Set the required secrets using `fly secrets set`. You can set multiple secrets at once.
    - Example command:

      ```bash
      fly secrets set SECRET_KEY_BASE="<generated_secret>" \
        GOOGLE_CLIENT_ID="<your_client_id>" \
        GOOGLE_CLIENT_SECRET="<your_client_secret>" \
        ... (other vars)
      ```

    - **Required Variables**:

    | Variable Name | Description | Example / Notes |
    | :--- | :--- | :--- |
    | `SECRET_KEY_BASE` | Phoenix secret key | Generate with `mix phx.gen.secret` locally |
    | `PHX_HOST` | The public domain of your app | e.g., `social-scribe.fly.dev` |
    | `GOOGLE_CLIENT_ID` | OAuth Client ID | Google Cloud Console |
    | `GOOGLE_CLIENT_SECRET` | OAuth Client Secret | Google Cloud Console |
    | `GOOGLE_REDIRECT_URI` | Auth Callback URL | `https://<YOUR_PHX_HOST>/auth/google/callback` |
    | `RECALL_API_KEY` | Recall.ai API Key | |
    | `RECALL_REGION` | Recall.ai Region | e.g., `us-west-2` |
    | `LLM_PROVIDER` | AI provider | `anthropic` (default) or `gemini` |
    | **Anthropic (default LLM)** | | |
    | `ANTHROPIC_BASE_URL` | Anthropic API base URL | Required when using default provider |
    | `ANTHROPIC_AUTH_TOKEN` | Anthropic API key | Required when using default provider |
    | `ANTHROPIC_MODEL` | Model name | e.g., `claude-3-5-sonnet-20241022` |
    | **Gemini (optional LLM)** | | |
    | `GEMINI_API_KEY` | Google Gemini API Key | Required only when `LLM_PROVIDER=gemini` |
    | `GEMINI_MODEL` | Gemini model | Optional; has a default when using Gemini |
    | `LINKEDIN_CLIENT_ID` | LinkedIn App ID | Developer Portal |
    | `LINKEDIN_CLIENT_SECRET` | LinkedIn App Secret | Developer Portal |
    | `LINKEDIN_REDIRECT_URI` | Callback URL | `https://<YOUR_PHX_HOST>/auth/linkedin/callback` |
    | `FACEBOOK_APP_ID` | Facebook App ID | Meta Developers |
    | `FACEBOOK_APP_SECRET` | Facebook App Secret | Meta Developers |
    | `FACEBOOK_REDIRECT_URI` | Callback URL | `https://<YOUR_PHX_HOST>/auth/facebook/callback` |
    | `HUBSPOT_CLIENT_ID` | HubSpot Client ID | HubSpot Developer |
    | `HUBSPOT_CLIENT_SECRET` | HubSpot Client Secret | HubSpot Developer |
    | `HUBSPOT_REDIRECT_URI` | Callback URL | `https://<YOUR_PHX_HOST>/auth/hubspot/callback` |
    | `POOL_SIZE` | DB Connection Pool | Default: `10` |

    *Note: `DATABASE_URL` is automatically set when you attach a Fly Postgres database.*
    *Note: `PORT` is automatically handled by Fly.io (defaults to 8080 as per `fly.toml`).*

4. **Deploy**
    - Run `fly deploy` to build and deploy your application.
    - Fly.io will use the `Dockerfile` in the root directory.
    - It will also run the release command defined in `fly.toml` (`/app/bin/migrate`) to run database migrations automatically on deployment.

5. **Troubleshooting**
    - **Logs**: Run `fly logs` to see live logs from your application.
    - **Status**: Run `fly status` to check the status of your machines.
    - **SSH**: Run `fly ssh console` to SSH into your running container for debugging.
