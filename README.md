# LinkedIn Safe Outreach

A low-volume, human-like LinkedIn connection request workflow built in n8n. Designed for founders/operators who want to start genuine conversations about automation — without triggering LinkedIn's anti-spam systems.

## What it does

1. Receives a JSON list of prospects via webhook.
2. Filters down to decision-makers (Founder / CEO / Owner / Director / Head of / Operations / Manager).
3. Generates a short, natural connection note by randomly rotating between 4 templates.
4. Sends one connection request per execution step via LinkedIn's voyager API.
5. Waits a randomized 60–180 seconds between requests.
6. Caps the run at a configurable max (default 15 prospects).
7. Logs every outcome (sent / failed) to Postgres table `leads.linkedin_outreach_log`.

## How it helps a business

- **Compliant outreach.** Mimics human pacing so the LinkedIn account stays healthy.
- **Quality over quantity.** 10–20 carefully personalized touches per day outperform mass spam in reply rate.
- **Auditable.** Every send is logged with timestamp, profile URL, template used, HTTP status, and failure reason.
- **Reusable.** POST any list to the webhook — same workflow handles any vertical or campaign.

## Customer / user journey

1. Operator prepares a JSON list of 10–20 fresh leads.
2. Operator POSTs them to the webhook URL.
3. Workflow filters out irrelevant titles.
4. For each qualified prospect, the workflow:
   - Rotates a template, fills in name/company.
   - Sends the connection request.
   - Logs the result to Postgres.
   - Waits 60–180s.
5. Operator queries `leads.linkedin_outreach_log` for daily review. Replies are handled manually in LinkedIn — this workflow does not auto-reply.

## Webhook input format

`POST https://YOUR_N8N_HOST/webhook/linkedin-safe-outreach`

Body:
```json
{
  "prospects": [
    {
      "first_name": "Jane",
      "last_name": "Doe",
      "job_title": "Founder",
      "company_name": "Acme Co",
      "linkedin_url": "https://www.linkedin.com/in/janedoe/",
      "country": "Germany"
    }
  ]
}
```

A bare array `[ {...}, {...} ]` also works.

## Country filter

The workflow only sends to EU/EEA prospects, in two tiers:

- **Priority (sent first):** Malta, United Kingdom, Germany, France, Netherlands, Sweden, Norway, Denmark, Finland — chosen for high English proficiency.
- **Secondary (sent after priority):** all other EU + EEA + Switzerland (Austria, Belgium, Bulgaria, Croatia, Cyprus, Czechia, Estonia, Greece, Hungary, Iceland, Ireland, Italy, Latvia, Liechtenstein, Lithuania, Luxembourg, Poland, Portugal, Romania, Slovakia, Slovenia, Spain, Switzerland).
- **Everything else** (including prospects with a blank `country` field) is dropped before sending.

`country` accepts full names ("Germany", "United Kingdom") or ISO codes ("DE", "GB", "UK") — case-insensitive. The chosen tier ends up in the Postgres log as `country_tier` (`priority` or `secondary`).

## Required credentials, APIs, and env vars

### Credentials (configured in n8n)

| Name in n8n          | Type                  | Used for                          | Status |
|----------------------|-----------------------|-----------------------------------|--------|
| `LinkedIn Session`   | HTTP Custom Auth      | Sending connection requests       | ✅ created |
| `Leadgen PostgreSQL` | Postgres              | Writing to outreach log table     | ✅ existing |
| `Gotify`             | HTTP Header Auth      | Error notifications               | ⚠️ needed for error handler |

### Environment variables (read by the workflow via `$env`)

Add to `/opt/leadgen-stack/.env` then restart `leadgen-n8n`:

| Var                          | Default | Purpose                              |
|------------------------------|---------|--------------------------------------|
| `LINKEDIN_MAX_PER_RUN`       | `15`    | Hard cap on requests per execution   |
| `LINKEDIN_MIN_DELAY_SEC`     | `60`    | Lower bound on inter-request delay   |
| `LINKEDIN_MAX_DELAY_SEC`     | `180`   | Upper bound on inter-request delay   |
| `GOTIFY_URL`                 | —       | Notification endpoint (for error handler) |

Defaults work without the env vars — they only override the built-in safety knobs.

## Database

Postgres table `leads.linkedin_outreach_log` on `leadgen-postgres / appointments`. Schema in [01-create-table.sql](01-create-table.sql). Already created.

Query the log:
```sql
SELECT ts, first_name, company_name, status, http_status, reason
FROM leads.linkedin_outreach_log
ORDER BY ts DESC
LIMIT 50;
```

## Files in this package

- `01-create-table.sql` — Postgres log table
- `02-linkedin-safe-outreach.workflow.json` — main outreach workflow
- `03-error-handler.workflow.json` — Gotify error handler (attach as Error Workflow)
- `04-lead-discovery.workflow.json` — optional lead generator (DuckDuckGo → JSON → outreach webhook)
- `docs/SETUP_WALKTHROUGH.md` — step-by-step bring-up
- `docs/TESTING_WORKFLOW.md` — how to dry-run before going live

## Optional companion: Lead Discovery (workflow #4)

A second workflow `LinkedIn Lead Discovery` that finds prospects on its own and POSTs them to the outreach webhook.

**How it works:**
1. Builds a Google-style query per priority country: `site:linkedin.com/in/ ("founder" OR "CEO" OR "owner" OR "managing director") "<country>"`
2. Runs it through DuckDuckGo HTML search (no API key, no signup, free)
3. Parses results into `{first_name, last_name, job_title, company_name, linkedin_url, country}` records
4. De-duplicates against `leads.linkedin_outreach_log` so already-contacted profiles are skipped
5. Aggregates the survivors into `{"prospects":[...]}`
6. POSTs to the outreach webhook → outreach workflow filters/paces/sends

**Tunable:** env var `DISCOVERY_PER_COUNTRY` (default 3) controls how many results to keep per country per run. With the default priority list of 9 countries, expect ~10–25 usable prospects per run after parsing + de-duping.

**Caveats:**
- Result quality varies — DDG snippets aren't structured data. Some prospects will land with `company_name=''` or a noisy `job_title`. The outreach filter drops anything not matching the decision-maker regex, so noise is contained.
- Hits DDG nicely with a 4-second pause between countries; safe to run a few times a day.
- For higher quality, swap the DuckDuckGo node for SerpAPI / Brave Search API — same shape, just a different HTTP call.

## Design principle

Intentionally **minimal and human-like**. Not built to scale to thousands of sends — that is a feature. LinkedIn's restrictions are unforgiving; a 15/day cadence with personalization will outperform any bulk tool over a 90-day window.
