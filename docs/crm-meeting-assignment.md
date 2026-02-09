# CRM Assignment for Meetings

This document describes how Social Scribe handles multiple CRM integrations when associating meetings with CRM contacts. The system supports automatic detection of the appropriate CRM provider based on meeting participants, as well as manual selection when auto-detection is ambiguous or unavailable.

## Overview

Each meeting can be associated with a single CRM provider (currently HubSpot or Salesforce). This association enables the system to:

- Search for contacts in the correct CRM when updating contact information
- Generate CRM-specific suggestions based on meeting transcripts
- Apply updates to the appropriate CRM system

The association is stored in the `meetings` table via the `crm_provider` field, which contains a string identifier like "hubspot" or "salesforce".

## Database Schema

The `meetings` table includes two CRM-related fields:

- `crm_provider` (string, nullable): The CRM provider identifier ("hubspot", "salesforce", etc.)
- `crm_contact_id` (string, nullable): Optional identifier for a specific contact within the CRM

These fields are indexed for efficient querying. Existing meetings created before this feature was added will have `crm_provider` set to `nil`.

## Auto-Detection Flow

### When Auto-Detection Runs

Auto-detection occurs automatically when a meeting is created from a completed Recall.ai bot. The process runs in `Meetings.create_meeting_from_recall_data/4`, which is called by `Bots.Processor.process_completed_bot/2` after a bot finishes recording.

Auto-detection only runs if `crm_provider` is `nil`. If a meeting already has a CRM provider assigned, the system skips auto-detection.

### How Auto-Detection Works

The auto-detection process (`Meetings.auto_detect_crm_provider/1`) follows these steps:

1. **Extract participant names**: The system retrieves all meeting participants from the `meeting_participants` table and extracts their names, filtering out empty or whitespace-only names.

2. **Get connected CRMs**: The system queries the `user_credentials` table to find all CRM credentials connected by the meeting owner. It checks all registered CRM providers (currently HubSpot and Salesforce) via `Crm.Registry.crm_providers()`.

3. **Search for matches**: For each participant name, the system searches across all connected CRMs using the CRM adapter's `search_contacts/2` function. Each CRM adapter implements its own search logic:
   - HubSpot uses the `/crm/v3/objects/contacts/search` endpoint
   - Salesforce uses the SOQL `FIND` query syntax

4. **Count matches per provider**: The system tracks how many participant names match contacts in each CRM. A match is counted when a CRM returns at least one contact for a participant name.

5. **Determine result**: Based on the match counts:
   - **Single match**: If exactly one CRM has matches, the system automatically sets `crm_provider` to that provider and logs the assignment.
   - **Multiple matches**: If multiple CRMs have matches, the system leaves `crm_provider` as `nil` and logs that user selection is required.
   - **No matches**: If no CRMs have matching contacts, the system leaves `crm_provider` as `nil` and logs that no matches were found.

### Auto-Detection Return Values

The `auto_detect_crm_provider/1` function returns one of three values:

- `{:ok, provider}`: Exactly one CRM has matching contacts. The provider string (e.g., "hubspot") is returned.
- `{:multiple_matches, providers}`: Multiple CRMs have matching contacts. A list of provider strings is returned.
- `{:no_matches}`: No CRMs have matching contacts, or no CRMs are connected.

### Example Auto-Detection Scenarios

**Scenario 1: Single Match**

- User has HubSpot and Salesforce connected
- Meeting participants: "John Doe", "Jane Smith"
- HubSpot search finds "John Doe" and "Jane Smith"
- Salesforce search finds no matches
- Result: `crm_provider` automatically set to "hubspot"

**Scenario 2: Multiple Matches**

- User has HubSpot and Salesforce connected
- Meeting participants: "John Doe"
- HubSpot search finds "John Doe"
- Salesforce search also finds "John Doe"
- Result: `crm_provider` remains `nil`, user must select manually

**Scenario 3: No Matches**

- User has HubSpot connected
- Meeting participants: "Unknown Person"
- HubSpot search finds no matches
- Result: `crm_provider` remains `nil`, user can manually select if desired

## Manual Assignment Flow

### When Manual Assignment is Needed

Users need to manually assign a CRM provider in these situations:

1. Auto-detection found multiple matches (multiple CRMs have contacts matching participants)
2. Auto-detection found no matches (no CRM contacts match participants)
3. The user wants to override the auto-detected provider
4. The meeting was created before auto-detection was implemented

### UI Flow for Manual Assignment

The manual assignment flow is handled in `MeetingLive.Show`:

1. **CRM Selector Display**: When `crm_provider` is `nil` and the user has at least one CRM connected, the UI displays a CRM selector showing buttons for each connected CRM (e.g., "Use HubSpot", "Use Salesforce").

2. **Provider Selection**: When the user clicks a CRM provider button, the `set_crm_provider` event is triggered with the selected provider string.

3. **Update Meeting**: The system calls `Meetings.update_meeting/2` to set the `crm_provider` field.

4. **UI Refresh**: After successful update, the UI refreshes to show the associated CRM button (e.g., "Update HubSpot") instead of the selector.

5. **Change CRM Option**: If the user has multiple CRMs connected and a provider is already set, a "Change CRM" button appears, which re-displays the CRM selector.

### Manual Assignment Events

The LiveView handles two key events for manual assignment:

- `handle_event("set_crm_provider", %{"provider" => provider}, socket)`: Sets the CRM provider on the meeting and updates the UI accordingly.
- `handle_event("show_crm_selector", _params, socket)`: Shows the CRM selector UI when the user wants to change the CRM.

### CRM Credential Building

Before displaying CRM options, the system builds a map of available CRM credentials using `build_crm_credentials/1`. This function:

1. Gets all registered CRM providers from `Crm.Registry.crm_providers()`
2. Filters providers based on configured adapter (if a specific adapter is configured for testing)
3. Queries `Accounts.get_user_crm_credential/2` for each provider
4. Returns a map of `%{provider => credential}` for connected CRMs only

## CRM Modal Flow

Once a CRM provider is assigned (either automatically or manually), users can interact with the CRM through the CRM modal component.

### Opening the CRM Modal

The CRM modal is opened via LiveView routes:

- `/dashboard/meetings/:id/crm/hubspot` for HubSpot
- `/dashboard/meetings/:id/crm/salesforce` for Salesforce
- `/dashboard/meetings/:id/crm/:provider` for generic provider support

The modal displays the `CrmModalComponent`, which is provider-agnostic and receives the provider as an assign.

### CRM Modal Functionality

The CRM modal (`CrmModalComponent`) provides:

1. **Contact Search**: Users can search for contacts in the assigned CRM by typing a query (minimum 2 characters). The search triggers an async message `{:crm_search, provider, query, credential}` which is handled by `CrmHandlers`.

2. **Contact Selection**: When a contact is selected, the system generates suggestions for updating that contact based on the meeting transcript. This triggers `{:crm_generate_suggestions, provider, contact, meeting, credential}`.

3. **Applying Updates**: Users can review and select which suggested updates to apply. When submitted, this triggers `{:crm_apply_updates, provider, updates, contact, credential}`.

All CRM operations are handled asynchronously via `CrmHandlers`, which delegates to the appropriate CRM adapter based on the provider.

## Technical Implementation Details

### CRM Registry

The `Crm.Registry` module serves as the single source of truth for CRM providers:

- `crm_providers/0`: Returns list of all registered provider strings
- `adapter_for/1`: Maps provider string to adapter module
- `provider_label/1`: Returns human-readable label for a provider

To add a new CRM provider:

1. Create an adapter module implementing `Crm.Behaviour` in `lib/social_scribe/crm/adapters/`
2. Add the provider to `Crm.Registry` providers map
3. Add a label to the labels map
4. Implement OAuth strategy if needed

### CRM Adapters

Each CRM adapter implements the `Crm.Behaviour` which defines:

- `search_contacts/2`: Search for contacts by query string
- `generate_suggestions/3`: Generate update suggestions from meeting transcript
- `apply_updates/3`: Apply updates to a contact

The adapters abstract away provider-specific API differences, allowing the rest of the system to work with any CRM provider.

### Meeting Context Functions

Key functions in `Meetings` context:

- `auto_detect_crm_provider/1`: Public function for auto-detecting CRM provider
- `detect_from_participants/2`: Private helper that searches participants across CRMs
- `search_contact_in_crm/3`: Private helper that delegates to CRM adapter
- `create_meeting_from_recall_data/4`: Creates meeting and runs auto-detection
- `update_meeting/2`: Updates meeting including `crm_provider` field

### LiveView Assigns

The `MeetingLive.Show` LiveView maintains several assigns related to CRM:

- `crm_credentials`: Map of `%{provider => credential}` for connected CRMs
- `crm_entries`: List of CRM entries to display (either selector options or associated CRM button)
- `crm_selection_options`: Options for CRM selector (when no provider is set)
- `show_crm_selector`: Boolean indicating whether to show CRM selector UI
- `crm_modal_provider`: Currently open CRM modal provider (if any)
- `crm_modal_provider_label`: Human-readable label for modal provider

## Error Handling

### Auto-Detection Errors

If auto-detection encounters errors (e.g., CRM API failures), the system:

- Logs a warning message
- Leaves `crm_provider` as `nil`
- Allows manual assignment via UI

The system does not fail meeting creation if auto-detection fails.

### Manual Assignment Errors

If manual assignment fails (e.g., database constraint violation), the system:

- Displays an error flash message to the user
- Keeps the existing `crm_provider` value
- Allows the user to retry

### CRM API Errors

CRM API errors during contact search or update operations are handled by `CrmHandlers`:

- Search errors: Display error message in contact search field
- Suggestion generation errors: Display error message in suggestions section
- Update errors: Display error message and allow retry

## Testing

Auto-detection is tested in `test/social_scribe/meetings_crm_auto_detect_test.exs`, which covers:

- Single match scenarios
- Multiple match scenarios
- No match scenarios
- Empty participant names
- Missing user credentials
- Missing calendar event user_id

Manual assignment is tested in `test/social_scribe_web/live/meeting_live/show_crm_test.exs` and related test files, which cover:

- Setting CRM provider via UI
- Changing CRM provider
- CRM selector display logic
- CRM modal functionality

## Future Enhancements

Potential improvements to the CRM assignment system:

1. **Contact ID Storage**: Store `crm_contact_id` when a contact is selected in the CRM modal, enabling faster lookups.

2. **Preference Learning**: Remember user's CRM preferences for specific contacts or domains to improve auto-detection accuracy.

3. **Multi-CRM Support**: Allow associating a meeting with multiple CRMs if contacts exist in multiple systems.

4. **Confidence Scoring**: Add confidence scores to auto-detection results to help users understand why a CRM was selected.

5. **Domain-Based Detection**: Use email domains from participants to infer CRM provider (e.g., @company.com might suggest a specific CRM).

6. **Calendar Event Metadata**: Use calendar event metadata or custom properties to hint at CRM provider.
