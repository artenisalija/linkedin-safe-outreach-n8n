# LinkedIn Safe Outreach — n8n workflow

A small, human-paced LinkedIn connection-request workflow for n8n. Pulls a list of prospects from a webhook, filters to decision-makers, rotates 4 connection-note templates, sends invites with randomized 60–180s delays, and logs every outcome to Postgres.

Built to stay inside LinkedIn's anti-spam radar — low volume, varied messaging, no aggressive automation.

## What's in here

| File | Purpose |
|------|---------|
| `01-create-table.sql` | Postgres log table |
| `02-linkedin-safe-outreach.workflow.json` | Main workflow (webhook trigger → filter → send → log → delay) |
| `03-error-handler.workflow.json` | Generic error handler that pings Gotify |

## Webhook payload

`POST /webhook/linkedin-safe-outreach`

```json
{
  "prospects": [
    {
      "first_name": "Jane",
      "last_name": "Doe",
      "job_title": "Founder",
      "company_name": "Acme Co",
      "linkedin_url": "https://www.linkedin.com/in/janedoe/"
    }
  ]
}
```

## How it works

1. **Webhook Trigger** receives the prospects array.
2. **Filter** keeps only profiles whose `job_title` matches Founder / CEO / Owner / Co-Founder / Director / Head of / Operations / Manager.
3. **Cap Per Run** trims to `LINKEDIN_MAX_PER_RUN` (default 15).
4. **Loop Each Prospect** iterates one prospect at a time.
5. **Pick Template & Personalize** randomly selects one of 4 connection-note templates and fills in the prospect's name + company. Notes are capped at 290 characters.
6. **Extract Public ID** parses the LinkedIn URL into a profile handle.
7. **Send Connection Request** calls LinkedIn's voyager API with the user's session cookies (configured via an HTTP Custom Auth credential). `neverError: true` so failures still flow through to the log step.
8. **Build Log Row** prepares the outcome record.
9. **Insert Outreach Log** writes to `leads.linkedin_outreach_log` via a parameterized Postgres query.
10. **Pick Random Delay** chooses a delay between `LINKEDIN_MIN_DELAY_SEC` (60) and `LINKEDIN_MAX_DELAY_SEC` (180) seconds.
11. **Wait** holds for the delay, then loops back.

## Credentials you'll need to wire

Open the workflow in the n8n UI and replace each placeholder credential reference with one from your instance:

- **LinkedIn Session** (HTTP Custom Auth) — your `li_at` and `JSESSIONID` cookies plus matching `csrf-token` header.
- **Postgres** — for the log table.
- **Gotify** (HTTP Header Auth) — only used by the error handler.

## Environment variables (optional)

| Var | Default |
|-----|---------|
| `LINKEDIN_MAX_PER_RUN` | 15 |
| `LINKEDIN_MIN_DELAY_SEC` | 60 |
| `LINKEDIN_MAX_DELAY_SEC` | 180 |

## Import

```bash
n8n import:workflow --input=02-linkedin-safe-outreach.workflow.json
n8n import:workflow --input=03-error-handler.workflow.json
```

Each JSON includes a top-level `id` field, which n8n v2+ requires for CLI import.

## Design principle

This is intentionally **low-volume**. 10–20 personalized invites per day will outperform any bulk LinkedIn tool over a 90-day window, and they won't get the sending account restricted.

## License

MIT
