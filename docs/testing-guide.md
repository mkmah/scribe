# Social Scribe - Complete Testing & Requirements Guide

This document provides a comprehensive overview of all implemented features and step-by-step testing instructions.

## Table of Contents

1. [Requirements Overview](#requirements-overview)
2. [Prerequisites for Testing](#prerequisites-for-testing)
3. [Environment Setup](#environment-setup)
4. [Step-by-Step Testing Guide](#step-by-step-testing-guide)
5. [Feature Implementation Checklist](#feature-implementation-checklist)

---

## Requirements Overview

### What This App Does (In Simple English)

Social Scribe is an AI-powered meeting assistant for financial advisors. Here's how it works:

1. **Connect Your Calendar**: You log in with Google and connect your calendar. The app shows your upcoming meetings.

2. **Send an AI Notetaker**: For any meeting, you can toggle a switch to have an AI bot join. The bot joins a few minutes before the meeting starts (you configure this).

3. **Get Automatic Transcriptions**: After the meeting, the bot provides a full transcript of what was said.

4. **AI-Generated Follow-ups**: The app uses AI to:
   - Draft a follow-up email summarizing the meeting
   - Suggest updates to your CRM contacts (HubSpot or Salesforce)

5. **CRM Integration**:
   - You can connect HubSpot or Salesforce via OAuth
   - For any meeting, you can search for a contact and see AI-suggested updates based on what was said
   - Review and apply those updates directly to the CRM

6. **Ask Questions About Contacts**: A chat interface lets you ask questions about your CRM contacts using @mentions (e.g., "What is @John Smith's company?")

---

## Prerequisites for Testing

### Required Accounts & API Keys

You'll need to set up the following:

1. **Google OAuth App** (Required for login and calendar)
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Google Calendar API
   - Create OAuth 2.0 credentials
   - Add `http://localhost:4000/auth/google/callback` to authorized redirect URIs
   - Add `webshookeng@gmail.com` as a test user

2. **Recall.ai Account** (Required for meeting transcription)
   - Sign up at [https://www.recall.ai/](https://www.recall.ai/)
   - Get your API key from the dashboard

3. **Google Gemini API Key** (Required for AI content generation)
   - Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create an API key

4. **HubSpot OAuth App** (Optional - for HubSpot CRM testing)
   - Go to [HubSpot Developer Portal](https://developers.hubspot.com/)
   - Create a new app
   - Install the app to get OAuth credentials
   - Required scopes: `crm.objects.contacts.read`, `crm.objects.contacts.write`, `oauth`

5. **Salesforce Connected App** (Optional - for Salesforce CRM testing)
   - Log in to your Salesforce org (Developer Edition is free)
   - Go to Setup → App Manager → New Connected App
   - Enable OAuth Settings
   - Set Callback URL: `http://localhost:4000/auth/salesforce/callback`
   - Selected OAuth Scopes: `api`, `refresh_token`, `full`
   - Save and note the Consumer Key and Consumer Secret

---

## Environment Setup

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd social_scribe
mix setup
```

### 2. Create Environment Variables

Create a `.env` file in the project root:

```bash
# Google OAuth (Required)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_REDIRECT_URI=http://localhost:4000/auth/google/callback

# Recall.ai (Required)
RECALL_API_KEY=your_recall_api_key
RECALL_REGION=us

# Google Gemini (Required)
GEMINI_API_KEY=your_gemini_api_key

# HubSpot (Optional)
HUBSPOT_CLIENT_ID=your_hubspot_client_id
HUBSPOT_CLIENT_SECRET=your_hubspot_client_secret

# Salesforce (Optional)
SALESFORCE_CLIENT_ID=your_salesforce_consumer_key
SALESFORCE_CLIENT_SECRET=your_salesforce_consumer_secret

# Database (Defaults shown)
DATABASE_URL=ecto://postgres:postgres@localhost/social_scribe_dev
```

### 3. Start the Application

```bash
source .env && mix phx.server
```

Visit `http://localhost:4000` in your browser.

---

## Step-by-Step Testing Guide

### Test 1: Google Login & Calendar Sync

**Purpose**: Verify you can log in with Google and see calendar events.

**Steps**:

1. Visit `http://localhost:4000`
2. Click "Sign in with Google"
3. Authorize the app with your Google account
4. After redirect, you should see the Dashboard
5. Verify you see upcoming calendar events
6. Click the toggle next to an event to enable recording

**Expected Result**:

- Successfully logged in
- Dashboard shows your Google Calendar events
- Toggle switches work for enabling/disabling recording

---

### Test 2: Connect Additional Google Accounts

**Purpose**: Verify multiple Google accounts can be connected.

**Steps**:

1. Go to Settings (click your name → Settings, or visit `/dashboard/settings`)
2. Under "Connected Google Accounts", click "Connect another Google Account"
3. Authorize with a different Google account
4. Verify both accounts appear in the settings

**Expected Result**:

- Multiple Google accounts can be connected
- Each account shows UID and email

---

### Test 3: Configure Bot Join Timing

**Purpose**: Configure how many minutes before the meeting the bot should join.

**Steps**:

1. Go to `/dashboard/settings`
2. Under "Bot Preferences", change "Join Minute Offset" to your preferred value (default is 2 minutes)
3. Click "Save"

**Expected Result**:

- Settings are saved
- Bot will join meetings X minutes before start time

---

### Test 4: Record a Meeting (Using Recall.ai)

**Purpose**: Verify the Recall.ai bot joins and records meetings.

**Preparation**: Create a test meeting on Google Calendar with a Zoom or Google Meet link.

**Steps**:

1. On the Dashboard, find your test meeting
2. Toggle "Record Meeting?" to ON
3. Join the actual meeting manually (with Zoom/Google Meet)
4. Verify the Recall.ai bot joins within your configured offset time
5. Speak in the meeting (test transcript content)
6. End the meeting after a few minutes
7. Wait 2-5 minutes for processing (Oban polling worker checks bot status)

**Expected Result**:

- Recall.ai bot appears in the meeting
- After the meeting, it appears under Past Meetings
- The meeting has a transcript

---

### Test 5: View Meeting Transcript & AI Follow-up Email

**Purpose**: Verify transcript storage and AI-generated email.

**Steps**:

1. Go to Meetings (`/dashboard/meetings`)
2. Click on a past meeting
3. Scroll to "Meeting Transcript" section
4. Scroll to "AI Draft: Follow-Up Email" section

**Expected Result**:

- Full transcript is visible with speaker names and text
- AI-generated follow-up email is displayed
- "Copy to clipboard" button works for the email

---

### Test 6: HubSpot Integration

**Purpose**: Connect HubSpot and update a contact from a meeting.

**Steps**:

**Part A - Connect HubSpot**:

1. Go to Settings (`/dashboard/settings`)
2. Under "Connected HubSpot Accounts", click "Connect HubSpot"
3. Authorize with your HubSpot account
4. Verify the account appears in settings

**Part B - Update Contact from Meeting**:

1. Navigate to a past meeting
2. Click "Update HubSpot Contact" button
3. In the modal, search for a contact (type at least 2 characters)
4. Select a contact from the dropdown
5. Wait for AI to generate suggestions
6. Review the suggestion cards showing:
   - Field label (e.g., "Email", "Phone")
   - Current value (strikethrough if exists)
   - Arrow indicator
   - AI-suggested new value
   - Checkbox to enable/disable each update
7. Uncheck any suggestions you don't want to apply
8. Click "Update HubSpot"

**Expected Result**:

- HubSpot account connects successfully
- Contact search returns matching contacts
- AI generates relevant suggestions based on meeting transcript
- Selected updates are applied to HubSpot contact
- Success message confirms the update

---

### Test 7: Salesforce Integration

**Purpose**: Connect Salesforce and update a contact from a meeting.

**Steps**:

**Part A - Create Salesforce Connected App** (if not done):

1. Log in to Salesforce Developer Edition
2. Go to Setup → App Manager
3. Click "New Connected App"
4. Fill in:
   - Connected App Name: "Social Scribe"
   - Enable OAuth Settings: Yes
   - Callback URL: `http://localhost:4000/auth/salesforce/callback`
   - Selected OAuth Scopes: `api`, `refresh_token`, `full`
5. Save and note Consumer Key/Secret

**Part B - Connect Salesforce**:

1. Go to Settings (`/dashboard/settings`)
2. Under "Connected Salesforce Accounts", click "Connect Salesforce"
3. Authorize with your Salesforce account
4. Verify the account appears in settings

**Part C - Update Contact from Meeting**:

1. Navigate to a past meeting
2. Click "Update Salesforce Contact" button
3. In the modal, search for a contact
4. Select a contact from the dropdown
5. Wait for AI to generate suggestions
6. Review and select updates
7. Click "Update Salesforce"

**Expected Result**:

- Salesforce account connects successfully
- Instance URL is stored correctly
- Contact search works
- AI suggestions are generated
- Updates are applied to Salesforce contact

---

### Test 8: CRM Chat (Ask Anything)

**Purpose**: Ask questions about CRM contacts using AI.

**Steps**:

1. Make sure you have at least one CRM connected (HubSpot or Salesforce)
2. Go to Chat (`/dashboard/chat`)
3. Type a question with a contact mention, e.g.:
   - "What is @John Smith's email address?"
   - "Tell me about @Jane Doe's company"
4. Send the message
5. View the AI response
6. Click "History" tab to see past conversations
7. Click "New Chat" to start fresh

**Expected Result**:

- Chat interface loads with welcome message
- @mentions are highlighted in blue
- AI searches the connected CRM for the contact
- AI responds with contact information
- Conversation history is preserved
- Multiple conversations can be created

---

### Test 9: Token Refresh (Background Worker)

**Purpose**: Verify OAuth tokens refresh automatically.

**Steps**:

1. Connect HubSpot or Salesforce
2. Wait for at least 5-10 minutes
3. The `CrmTokenRefresher` worker runs every 5 minutes
4. Make an API call (search contacts, update contact)

**Expected Result**:

- Token refresh happens automatically
- API calls continue working without requiring re-authentication

---

## Feature Implementation Checklist

### ✅ Existing Functionality (Already Implemented)

| Feature | Status | Notes |
| --------- | -------- | ------- |
| Google OAuth Login | ✅ Complete | Ueberauth strategy implemented |
| Multiple Google Accounts | ✅ Complete | Can connect multiple accounts |
| Calendar Event Sync | ✅ Complete | Pulls events from Google Calendar |
| Meeting Toggle (Record?) | ✅ Complete | Toggle in dashboard for each event |
| Recall.ai Bot Join | ✅ Complete | Bot joins configured minutes before start |
| Transcript Storage | ✅ Complete | Full transcript with speaker identification |
| Meeting Participants | ✅ Complete | Shows who attended the meeting |
| Platform Logo Detection | ✅ Complete | Detects Zoom, Google Meet, Teams |
| AI Follow-up Email | ✅ Complete | Uses Google Gemini API |
| Bot Status Polling | ✅ Complete | Oban worker checks every 2 minutes |
| HubSpot OAuth | ✅ Complete | Custom Ueberauth strategy |
| HubSpot Contact Search | ✅ Complete | Search via HubSpot API |
| HubSpot AI Suggestions | ✅ Complete | Generates updates from transcript |
| HubSpot Modal UI | ✅ Complete | Matches design spec |
| HubSpot Token Refresh | ✅ Complete | Automatic refresh every 5 minutes |
| Salesforce OAuth | ✅ Complete | Custom Ueberauth strategy with instance_url |
| Salesforce Contact Search | ✅ Complete | SOSL query search |
| Salesforce AI Suggestions | ✅ Complete | Uses same AI as HubSpot |
| Salesforce Modal UI | ✅ Complete | Generic CRM modal component |
| Salesforce Token Refresh | ✅ Complete | Unified token refresher worker |
| CRM Chat Interface | ✅ Complete | @mentions, conversation history |
| Chat AI Integration | ✅ Complete | Answers questions about CRM data |
| CRM Abstraction Layer | ✅ Complete | Generic behavior for all CRMs |

### 🎨 UI Components (Matching Design Spec)

| Component | Status | Design Match |
| ----------- | -------- | -------------- |
| Contact Search Dropdown | ✅ Complete | Avatar, email, company display |
| Suggestion Cards | ✅ Complete | Checkbox, strikethrough old value, arrow, new value |
| Value Comparison | ✅ Complete | Old → New visual with arrow |
| Modal Footer | ✅ Complete | Cancel + Update buttons, disabled state |
| Empty State | ✅ Complete | "No update suggestions" message |
| Loading States | ✅ Complete | Spinners for search and generation |
| HubSpot Colors/Styles | ✅ Complete | Custom Tailwind colors |
| Chat Interface | ✅ Complete | Modern ChatGPT-like UI |

### 🧪 Test Coverage

| Area | Test Files | Status |
| ------ | ------------ | -------- |
| Accounts & Auth | `accounts_test.exs` | ✅ |
| Google Calendar | `google_calendar_test.exs` | ✅ |
| Meetings (Show & Index) | `meeting_live_test.exs` | ✅ |
| AI Content Generation | `ai_content_generator_test.exs` | ✅ |
| HubSpot Integration | `hubspot_test.exs` | ✅ |
| Salesforce Auth | `salesforce_auth_test.exs` | ✅ |
| Salesforce Adapter | `adapters/salesforce_test.exs` | ✅ |
| CRM Chat | `crm_chat_live_test.exs` | ✅ |
| Controllers | `auth_controller_test.exs` | ✅ |

---

## Running Tests

To run the full test suite:

```bash
mix test
```

To run tests for a specific module:

```bash
mix test test/social_scribe/crm/adapters/salesforce_test.exs
```

To run tests with coverage:

```bash
mix test --cover
```

---

## Troubleshooting

### Issue: OAuth Callback Fails

- Verify redirect URIs match exactly (including http:// vs https://)
- Check that test user is added to OAuth app

### Issue: Bot Doesn't Join Meeting

- Verify Recall.ai API key is valid
- Check meeting has a valid Zoom or Google Meet link
- Check logs for any errors

### Issue: No Transcript After Meeting

- Wait up to 5 minutes for polling to complete
- Check Oban dashboard at `/dev/oban` for job status
- Verify Recall.ai bot successfully joined and recorded

### Issue: CRM Search Returns Empty

- Verify OAuth scopes include contact read access
- Check that contacts exist in your CRM
- Try searching with different name variations

### Issue: Token Expired Errors

- Wait for token refresher to run (every 5 minutes)
- Manually trigger a new CRM search to force token check
- Re-authenticate if refresh token is invalid

---

## Development Notes

### Key Files by Feature

**Authentication & OAuth**:

- `lib/social_scribe_web/controllers/auth_controller.ex` - OAuth callbacks
- `lib/ueberauth/strategy/google.ex` - Google strategy
- `lib/ueberauth/strategy/salesforce.ex` - Salesforce strategy
- `lib/ueberauth/strategy/hubspot.ex` - HubSpot strategy

**Calendar & Meetings**:

- `lib/social_scribe/google_calendar.ex` - Calendar sync
- `lib/social_scribe/recall.ex` - Recall.ai API client
- `lib/social_scribe/workers/bot_status_poller.ex` - Bot polling worker

**CRM Integration**:

- `lib/social_scribe/crm/` - CRM abstraction layer
- `lib/social_scribe/crm/adapters/hubspot.ex` - HubSpot adapter
- `lib/social_scribe/crm/adapters/salesforce.ex` - Salesforce adapter
- `lib/social_scribe/crm/chat.ex` - Chat functionality

**UI Components**:

- `lib/social_scribe_web/live/meeting_live/show.ex` - Meeting details page
- `lib/social_scribe_web/live/meeting_live/crm_modal_component.ex` - Generic CRM modal
- `lib/social_scribe_web/live/crm_chat_live.ex` - Chat interface
- `lib/social_scribe_web/components/modal_components.ex` - Reusable UI components

**Background Workers**:

- `lib/social_scribe/workers/crm_token_refresher.ex` - Unified token refresher
- `lib/social_scribe/workers/bot_status_poller.ex` - Meeting bot polling

---

## Next Steps for Deployment

1. **Environment Variables**: Set all production environment variables
2. **Database**: Configure production database (Cloud SQL recommended for GCP)
3. **OAuth Callbacks**: Update redirect URIs to production domain
4. **SECRET_KEY_BASE**: Generate with `mix phx.gen.secret`
5. **Build Release**: `mix release`
6. **Deploy**: Use Gigalixir, Fly.io, or containerize with Docker

---

## Summary

This application fulfills all requirements from the original specification:

1. ✅ Google OAuth login with calendar sync
2. ✅ Multiple Google account support
3. ✅ Recall.ai integration for meeting transcription
4. ✅ AI-generated follow-up emails
5. ✅ HubSpot OAuth and contact updates
6. ✅ Salesforce OAuth and contact updates
7. ✅ Chat interface for CRM questions
8. ✅ Modern UI matching the design specification
9. ✅ Comprehensive test coverage
10. ✅ Clean code with CRM abstraction for future providers

The application is production-ready and can be deployed after configuring production environment variables and OAuth callback URLs.
