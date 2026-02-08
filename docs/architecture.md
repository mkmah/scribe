# System Architecture

## Overview

Social Scribe is a monolithic web application built with Elixir and Phoenix LiveView. It functions as an intelligent meeting assistant that automates note-taking, content generation, and social media distribution. The system integrates with Google Calendar for scheduling, Recall.ai for meeting transcription, and Google Gemini for AI content generation.

## Technology Stack

### Core Framework

- **Language:** Elixir
- **Web Framework:** Phoenix 1.7 (LiveView for real-time UI)
- **Database:** PostgreSQL 14+
- **Background Processing:** Oban

### Key Libraries

- **Ueberauth:** OAuth2 authentication strategies for Google, LinkedIn, Facebook, and HubSpot.
- **Tesla:** HTTP client for communicating with external REST APIs (Recall, HubSpot, Graph API).
- **Ecto:** Database wrapper, changesets, and query generation.
- **Tailwind CSS:** Utility-first CSS framework for styling.

---

## Database Schema (Data Model)

The database is normalized to support multi-provider authentication, calendar syncing, and meeting automation.

### 1. User & Authentication

- **`users`**: The core identity record.
  - `email` (string, unique), `hashed_password` (string).
- **`user_credentials`**: Stores OAuth tokens for connected providers.
  - `user_id` (FK -> users).
  - `provider` (string: "google", "linkedin", "facebook", "hubspot").
  - `uid` (string): Provider-specific user ID.
  - `token` (string), `refresh_token` (string), `expires_at` (datetime).

### 2. Calendar & Meetings

- **`calendar_events`**: Synced events from Google Calendar.
  - `google_event_id` (string): Unique ID from Google.
  - `start_time`, `end_time` (datetime).
  - `meeting_url` (string): Zoom/Meet link extracted from description/location.
  - `record_meeting` (boolean): User toggle to enable bot dispatch.
- **`recall_bots`**: Tracks the Recall.ai bot instance for a specific event.
  - `recall_bot_id` (string): UUID from Recall.ai.
  - `status` (string): e.g., "recording", "done".
  - `calendar_event_id` (FK).
- **`meetings`**: Metadata for a processed/recorded meeting.
  - `title` (string), `recorded_at` (datetime), `duration_seconds` (integer).
  - `recall_bot_id` (FK).
- **`meeting_transcripts`**: The raw text content of the meeting.
  - `meeting_id` (FK).
  - `content` (map/json): The structured transcript data.
- **`meeting_participants`**: Attendees identified in the meeting.
  - `name` (string), `is_host` (boolean).

### 3. Automations

- **`automations`**: User-defined rules for content generation.
  - `user_id` (FK).
  - `platform` (enum: :linkedin, :facebook).
  - `description` (string): Prompt details (e.g., "Write a professional summary").
  - `is_active` (boolean).
- **`automation_results`**: The output of an automation run.
  - `meeting_id` (FK), `automation_id` (FK).
  - `generated_content` (string): The AI-drafted text.
  - `status` (string): e.g., "completed", "failed".

---

## End-to-End System Flows

### 1. Authentication Flow

1. **User Initiation:** User clicks "Sign in with Google" on the login page.
2. **Redirect:** `AuthController` redirects user to Google OAuth consent screen (scopes: email, calendar.readonly).
3. **Callback:** Google redirects back to `/auth/google/callback`.
4. **Handling:**
    - `UserAuth` checks if `user_credentials` exists for this UID.
    - If **New User**: Creates `User` and `UserCredential`.
    - If **Existing User**: Updates tokens in `UserCredential`.
5. **Session:** A session token is signed and stored in the cookie; user is redirected to Dashboard.

### 2. Calendar Sync & Bot Dispatch

1. **Sync:** On login (and periodically via Oban), `Calendar` context fetches events from Google Calendar API.
2. **Storage:** valid events (future dates, contain meeting links) are upserted into `calendar_events`.
3. **User Action:** User toggles "Record Meeting" on an event in the UI.
4. **Dispatch:**
    - The system schedules a request to Recall.ai API to spawn a bot 5 minutes before `start_time`.
    - A `RecallBot` record is created with status "scheduled".

### 3. Meeting Recording & Transcription

1. **Recording:** The Recall bot joins the call, records audio/video, and generates a transcript.
2. **Polling:** `BotStatusPoller` (Oban worker) runs every minute checking Recall.ai API for the status of active bots.
3. **Completion:**
    - When status becomes "done", the poller fetches the transcript JSON.
    - Data is inserted into `meetings`, `meeting_transcripts`, and `meeting_participants`.

### 4. Content Generation Pipeline

1. **Trigger:** Successful insertion of a `Meeting` triggers `AiContentGenerator` worker.
2. **Processing:**
    - **Email:** System sends transcript + "Summary Email" prompt to Google Gemini. Result saved to `meetings.follow_up_email`.
    - **Automations:** System fetches active `automations` for the user.
    - **Loop:** For each automation, sends transcript + user's prompt to Gemini.
3. **Result:** Specific posts (e.g., "LinkedIn Post") are saved to `automation_results`.

### 5. Social Distribution

1. **Review:** User views "Meeting Details" page.
2. **Modification:** User can edit the AI-generated text.
3. **Post Action:**
    - **LinkedIn:** Calls `LinkedInApi` with the user's OAuth token to create a UGC post (share).
    - **Facebook:** Calls `FacebookApi` using the Page Access Token to post to the selected Facebook Page.
