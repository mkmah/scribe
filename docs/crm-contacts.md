# CRM Contacts Explained

## What is a "Contact" in CRMs?

A **Contact** in CRM systems (HubSpot, Salesforce) represents a **person** you do business with - typically a client, prospect, or lead.

### Contact Information Includes

| Field | Example |
| ------- | -------- |
| Name | John Smith |
| Email | <john@example.com> |
| Phone | (555) 123-4567 |
| Company | Acme Corp |
| Job Title | CFO |
| Notes/History | Past interactions, meetings, calls |

---

## How Meetings Relate to Contacts

Here's the **key insight**: Financial advisors have meetings with people (contacts). During those meetings, the contact might mention things that should be updated in the CRM.

### Example Scenario

**Before Meeting** - Your CRM shows:

```text
Contact: John Smith
  Email:   john@old-company.com
  Phone:   (555) 000-0000
  Company: Old Company Inc
  Title:   CFO
```

**During Meeting** - John says:
> "Hey, I changed jobs! I'm now at TechStart as VP of Sales,
> and my new email is <john@techstart.io>"

**After Meeting** - The AI analyzes the transcript and suggests:

- Email: `john@old-company.com` → `john@techstart.io`
- Company: `Old Company Inc` → `TechStart`
- Title: `CFO` → `VP of Sales`

You review and click "Update" — the CRM contact is now current!

---

## The Purpose of Social Scribe

Social Scribe automates the flow from conversation to CRM updates.

```text
┌─────────────────────────────────────────────────────────────┐
│                    MEETING HAPPENS                           │
│              (Financial Advisor + Client)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              AI BOT JOINS & RECORDS                          │
│                    (Recall.ai)                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              FULL TRANSCRIPT AVAILABLE                       │
│            "John changed his email to..."                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              AI ANALYZES TRANSCRIPT                          │
│         "I should update the CRM contact!"                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           YOU REVIEW & SUGGESTIONS TO CRM                    │
│      Update John's email, company, title...                  │
└─────────────────────────────────────────────────────────────┘
```

---

## The Chat Feature Also Uses Contacts

When you chat with the AI and ask:
> "What is @John Smith's company?"

The AI searches your CRM for contacts matching "John Smith" and answers based on the CRM data. This is useful for quickly recalling information about clients.

---

## Summary: The Core Concepts

| Concept | Purpose |
| --------- | --------- |
| **Meeting** | Where conversations happen |
| **Transcript** | Record of what was said |
| **Contact** | The person's permanent record in CRM |
| **AI Suggestions** | Bridge between what was said and what should be updated in CRM |

### The Problem This Solves

Without Social Scribe:

- Meeting ends
- You try to remember what was said
- You manually log into HubSpot/Salesforce
- You update each field by hand
- Easy to miss important details

With Social Scribe:

- AI bot records everything
- AI analyzes and suggests updates
- You review and click "Update"
- Done!

---

## How It Works in the App

1. **Connect a CRM** (HubSpot or Salesforce) via OAuth
2. **Record a meeting** with the Recall.ai bot
3. **Open a past meeting** and click "Update HubSpot/Salesforce Contact"
4. **Search for a contact** from that meeting
5. **Review AI suggestions** based on the transcript
6. **Apply updates** to your CRM with one click
