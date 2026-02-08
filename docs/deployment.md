# Deployment Guide (Railway)

## Prerequisites

- Reliable GitHub repository containing the latest code.
- A [Railway](https://railway.app/) account.

## Deployment Steps

1. **Create New Project**
    - Log in to Railway.
    - Click "New Project" -> "Deploy from GitHub repo".
    - Select the `social_scribe` repository.

2. **Add Database**
    - In your project dashboard, click "New" -> "Database" -> "PostgreSQL".
    - Railway will automatically provision a database and provide a `DATABASE_URL` environment variable.

3. **Configure Environment Variables**
    - Go to the "Settings" or "Variables" tab of your application service.
    - Add the following required variables:

    | Variable Name | Description | Example / Notes |
    | :--- | :--- | :--- |
    | `SECRET_KEY_BASE` | Phoenix secret key | Generate with `mix phx.gen.secret` locally |
    | `PHX_HOST` | The public domain of your app | e.g. `social-scribe-production.up.railway.app` |
    | `GOOGLE_CLIENT_ID` | OAuth Client ID | Google Cloud Console |
    | `GOOGLE_CLIENT_SECRET` | OAuth Client Secret | Google Cloud Console |
    | `GOOGLE_REDIRECT_URI` | Auth Callback URL | `https://<YOUR_PHX_HOST>/auth/google/callback` |
    | `RECALL_API_KEY` | Recall.ai API Key | |
    | `RECALL_REGION` | Recall.ai Region | e.g., `us-west-2` |
    | `GEMINI_API_KEY` | Google Gemini API Key | Google AI Studio |
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

    *Note: `DATABASE_URL` and `PORT` are automatically handled by Railway.*

4. **Build and Deploy**
    - Railway automatically detects the `Dockerfile` in the root.
    - Push changes to your main branch to trigger a deployment.
    - Monitor the "Deploy Logs" for successful build and startup.

5. **Post-Deployment**
    - Once deployed, run migrations via the Railway CLI or by adding a start command if not auto-handled (The Dockerfile launches the server, migrations typically run on startup if configured in `release.ex` or need to be run manually).
    - To run migrations manually via Railway CLI: `railway run mix ecto.migrate` (if entering the specific container context) or utilize a release command if set up in `rel/`.
    *Note: The current `Dockerfile` CMD just starts the server. Ensure migrations are part of your startup script or run them as a one-off command.*
