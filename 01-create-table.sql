-- LinkedIn Safe Outreach — logging table
-- Run on leadgen-postgres / appointments / leads schema

CREATE TABLE IF NOT EXISTS leads.linkedin_outreach_log (
  id              BIGSERIAL PRIMARY KEY,
  ts              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  linkedin_url    TEXT NOT NULL,
  public_id       TEXT,
  first_name      TEXT,
  last_name       TEXT,
  company_name    TEXT,
  job_title       TEXT,
  template_index  INT,
  connection_note TEXT,
  status          TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'skipped')),
  http_status     INT,
  reason          TEXT
);

CREATE INDEX IF NOT EXISTS linkedin_outreach_log_url_idx ON leads.linkedin_outreach_log (linkedin_url);
CREATE INDEX IF NOT EXISTS linkedin_outreach_log_ts_idx ON leads.linkedin_outreach_log (ts DESC);
