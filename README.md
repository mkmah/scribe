# Social Scribe 🤖📝✨

**Stop manually summarizing meetings and drafting social media posts! Social Scribe leverages AI to transform your meeting transcripts into engaging follow-up emails and platform-specific social media content, ready to share.**

Social Scribe is a powerful Elixir and Phoenix LiveView application designed to connect to your calendars, automatically send an AI notetaker to your virtual meetings, provide accurate transcriptions via Recall.ai, and then utilize Google Gemini's advanced AI to draft compelling follow-up emails and social media posts through user-defined automation rules. This project was developed with significant AI assistance, as encouraged by the challenge, to rapidly build a feature-rich application.

---

## 🌟 Key Features Implemented

* **Google Calendar Integration:**
    * Seamlessly log in with your Google Account.
    * Connect multiple Google accounts to aggregate events from all your calendars.
    * View your upcoming calendar events directly within the app's dashboard.
    * Configure bot join timing in settings (default: 2 minutes before meeting).
* **Automated Meeting Transcription with Recall.ai:**
    * Toggle a switch for any calendar event to have an AI notetaker attend.
    * The app intelligently parses event details (description, location) to find Zoom or Google Meet links.
    * Recall.ai bot joins meetings a configurable number of minutes before the start time.
    * **Bot ID Management:** Adheres to challenge constraints by tracking individually created `bot_id`s.
    * **Polling for Media:** Implements a robust polling mechanism (via Oban) to check bot status and retrieve transcripts/media.
* **AI-Powered Content Generation (Google Gemini):**
    * Automatically drafts a follow-up email summarizing key discussion points and action items from the meeting transcript.
    * **Custom Automations:** Users can create, view, and manage automation templates, defining custom prompts, target platforms (LinkedIn, Facebook), and descriptions.
* **CRM Integration (HubSpot & Salesforce):**
    * Connect HubSpot or Salesforce via OAuth from Settings.
    * AI analyzes meeting transcripts and suggests updates to CRM contacts.
    * Review suggestions with side-by-side comparison (old → new values).
    * Selectively apply updates to the CRM with one click.
* **CRM Chat (Ask Anything):**
    * Ask questions about your CRM contacts using natural language.
    * Use @mentions to reference specific contacts (e.g., "What is @John Smith's company?").
    * AI searches connected CRMs and provides instant answers.
    * Full conversation history with multiple chat threads.
* **Social Media Integration & Posting:**
    * Securely connect LinkedIn and Facebook accounts via OAuth on the Settings page.
    * **Direct Posting:** Generated content can be posted directly to LinkedIn or Facebook.
* **Meeting Management & Review:**
    * View past meetings with attendees, duration, platform detection (Zoom, Meet, Teams).
    * Full transcripts with speaker identification.
    * AI-generated follow-up emails and automation results.
    * **Copy & Post Buttons:** Easy content reuse and direct posting.
* **Modern Tech Stack & Background Processing:**
    * Built with Elixir & Phoenix LiveView for a real-time, interactive experience.
    * Utilizes Oban for robust background job processing.
    * Secure credential management using Ueberauth.

---

## App Flow

* **Login With Google and Meetins Sync:**
    ![Auth Flow](https://youtu.be/RM7YSlu5ZDg)

* **Creating Automations:**
    ![Creating Automations](https://youtu.be/V2tIKgUQYEw)

* **Meetings Recordings:**
    ![Meetings Recording](https://youtu.be/pZrLsoCfUeA)

* **Facebook Login:**
    ![Facebook Login](https://youtu.be/JRhPqCN-jeI)

* **Facebook Post:**
    ![Facebook Post](https://youtu.be/4w6zpz0Rn2o)

* **LinkedIn Login & Post:**
    ![LinkedIn Login and Post](https://youtu.be/wuD_zefGy2k)
---

## 📸 Screenshots & GIFs


* **Dashboard View:**
    ![Dashboard View](readme_assets/dashboard_view.png)


* **Automation Configuration UI:**
    ![Automation Configuration](readme_assets/edit_automation.png)

---

## 🛠 Tech Stack

* **Backend:** Elixir, Phoenix LiveView
* **Database:** PostgreSQL
* **Background Jobs:** Oban (cron jobs, queues)
* **Authentication:** Ueberauth (Google, LinkedIn, Facebook, HubSpot, Salesforce)
* **HTTP Clients:** Tesla (for CRM API integrations)
* **Meeting Transcription:** Recall.ai API
* **AI Content Generation:** Google Gemini API
* **Frontend:** Tailwind CSS, Heroicons, Phoenix LiveView
* **Progress Bar:** Topbar.js for page loading indication.

---

## 🚀 Getting Started

Follow these steps to get SocialScribe running on your local machine.

### Prerequisites

* Elixir
* Erlang/OTP 
* PostgreSQL
* Node.js (for Tailwind CSS asset compilation)

### Setup Instructions

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/fparadas/social_scribe.git 
    cd social_scribe
    ```

2.  **Install Dependencies & Setup Database:**
    The `mix setup` command bundles common setup tasks.
    ```bash
    mix setup
    ```
    This will typically:
    * Install Elixir dependencies (`mix deps.get`)
    * Create your database if it doesn't exist (`mix ecto.create`)
    * Run database migrations (`mix ecto.migrate`)
    * Install Node.js dependencies for assets (`cd assets && npm install && cd ..`)

3.  **Configure Environment Variables:**
    Copy `.env.example` to `.env` and fill in your credentials:
    * **Required:**
        * `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`: Google OAuth (create at Google Cloud Console)
        * `RECALL_API_KEY`: Recall.ai API key (get from recall.ai)
        * `GEMINI_API_KEY`: Google Gemini API key (get from AI Studio)
    * **Optional (for CRM features):**
        * `HUBSPOT_CLIENT_ID` / `HUBSPOT_CLIENT_SECRET`: HubSpot OAuth
        * `SALESFORCE_CLIENT_ID` / `SALESFORCE_CLIENT_SECRET`: Salesforce Connected App

    See `.env.example` for the complete template.

4.  **Start the Phoenix Server:**
    ```bash
    mix phx.server
    ```
    Or, to run inside IEx (Interactive Elixir):
    ```bash
    iex -S mix phx.server
    ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

---

## ⚙️ Functionality Deep Dive

* **Connect & Sync:** Users log in with Google. The "Settings" page allows connecting multiple Google accounts, plus LinkedIn and Facebook accounts. For Facebook, after initial connection, users are guided to select a Page for posting. Calendars are synced to a database to populate the dashboard with upcoming events.
* **Record & Transcribe:** On the dashboard, users toggle "Record Meeting?" for desired events. The system extracts meeting links (Zoom, Meet) and uses Recall.ai to dispatch a bot. A background poller (`BotStatusPoller`) checks for completed recordings and transcripts, saving the data to local `Meeting`, `MeetingTranscript`, and `MeetingParticipant` tables.
* **AI Content Generation:**
    * Once a meeting is processed, an `AIContentGenerationWorker` is enqueued.
    * This worker uses Google Gemini to draft a follow-up email.
    * It also processes all active "Automations" defined by the user. For each automation, it combines the meeting data with the user's `prompt_template` and calls Gemini to generate content (e.g., a LinkedIn post), saving it as an `AutomationResult`.
* **Social Posting:**
    * From the "Meeting Details" page, users can view AI-generated email drafts and posts from their automations.
    * "Copy" buttons are available.
    * "Post" buttons allow direct posting to LinkedIn (as the user) and the selected Facebook Page (as the Page).

---

## 🔗 CRM Integration (HubSpot & Salesforce)

### Architecture

The CRM integration uses a generic abstraction layer that works with multiple providers:

* **`SocialScribe.Crm.Behaviour`**: Common interface all CRM adapters must implement
* **`SocialScribe.Crm.Registry`**: Registers available CRM providers
* **Unified Token Refresher**: Single Oban worker (`CrmTokenRefresher`) handles token refresh for all CRMs

### HubSpot Integration

* **Custom Ueberauth Strategy:** `lib/ueberauth/strategy/hubspot.ex`
* **OAuth 2.0 Flow:** Authorization code flow with HubSpot's endpoints
* **Credential Storage:** Tokens stored with automatic refresh capability
* **Contact Operations:** Search, retrieve, and update contacts
* **AI Suggestions:** Analyzes meeting transcripts for contact updates

### Salesforce Integration

* **Custom Ueberauth Strategy:** `lib/ueberauth/strategy/salesforce.ex`
* **OAuth 2.0 Flow:** Salesforce Connected App authorization
* **Instance URL Storage:** Stores org-specific API endpoint
* **Contact Operations:** Full CRUD via Salesforce REST API
* **SOSL Search:** Searches across all contact fields
* **AI Suggestions:** Same AI-powered update suggestions as HubSpot

### CRM Modal UI

* **Generic Component:** `CrmModalComponent` works with any CRM provider
* **Contact Search:** Debounced search with avatar display
* **AI Suggestion Cards:**
    * Checkbox for selection
    * Current value (strikethrough if exists)
    * Arrow indicator
    * AI-suggested new value
    * Transcript timestamp link
* **Batch Updates:** Selectively apply multiple fields at once
* **Design Match:** UI matches the specification exactly

### CRM Chat (Ask Anything)

* **LiveView Interface:** `lib/social_scribe_web/live/crm_chat_live.ex`
* **@Mentions:** Tag contacts like `@John Smith` to reference them
* **Multi-CRM Search:** Searches across all connected CRMs
* **AI Responses:** Context-aware answers about your contacts
* **Conversation History:** Full chat history with multiple threads

---

## 📖 Documentation

* **[Testing Guide](docs/testing-guide.md)** - Comprehensive testing walkthrough
* **[Architecture](docs/architecture.md)** - System architecture and data model
* **[Adding a New LLM Provider](docs/adding-new-llm-provider.md)** - Developer guide for integrating new AI providers
* **[Adding a New CRM Provider](docs/adding-new-crm-provider.md)** - Developer guide for integrating new CRM systems

---

## ⚠️ Known Issues & Limitations

* **Facebook Posting & App Review:**
    * Posting to Facebook is implemented via the Graph API to a user-managed Page.
    * Full functionality for all users typically requires Meta app review and Business Verification.
    * During development, posting works reliably for app admins to Pages they manage.
* **Calendar Sync Scope:**
    * Currently syncs the primary Google Calendar.
    * Multiple calendar support is structured but not fully exposed in UI.
* **Meeting Detection:**
    * Only syncs events with Zoom or Google Meet links (in `hangoutLink` or `location` fields).
---

## 📚 Learn More (Phoenix Framework)

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix