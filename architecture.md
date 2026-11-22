# Architecture: DataPilot (a rebuild of Dataimporter.io's core features)

## Stack

| layer                 | choice                                                    | why                                                                                                                                                                                                                                                  |
| --------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| web app               | **Next.js 15 (App Router) + TypeScript**                  | Server Components for the wizard screens, Server Actions for mutations, React for the interactive mapping/preview UIs. The import wizard is form-heavy — RSC keeps it fast.                                                                          |
| styling               | **Tailwind CSS + shadcn/ui**                              | Utility-first with accessible, copy-paste components. Tokens will come from replica-design.                                                                                                                                                          |
| database              | **PostgreSQL 16 on Supabase**                             | One managed Postgres. JSON columns for flexible connector configs, `timestamptz` everywhere, row-level security possible, plus Supabase gives us realtime for job progress.                                                                          |
| ORM                   | **Drizzle ORM**                                           | Type-safe SQL builder that maps 1:1 to our schema, no magic. Explicit queries make Salesforce API orchestration predictable.                                                                                                                         |
| auth                  | **Salesforce OAuth 2.0 (Web Server flow) + iron-session** | Users authenticate _through_ their Salesforce org — no separate password system. `iron-session` holds the encrypted session cookie. We store SF access/refresh tokens in Postgres (AES-256-GCM encrypted at rest via app-layer envelope encryption). |
| worker queue          | **Trigger.dev v3**                                        | Durable, retriable background jobs with built-in scheduling (cron), concurrency control, progress reporting, and a dashboard. Runs CSV parsing, Bulk API batches, backup snapshots, and flow orchestration. Alternative: BullMQ on a Fly worker.     |
| file / object storage | **Cloudflare R2**                                         | S3-compatible, zero egress fees. Stores uploaded CSVs, backup snapshots (gzipped JSONL), and exported result files.                                                                                                                                  |
| email                 | **Resend**                                                | Transactional emails for job success/failure notifications and schedule alerts.                                                                                                                                                                      |
| realtime              | **Supabase Realtime (Postgres changes)**                  | Live progress updates on S11 (job execution screen) — subscribe to `job_runs.progress_pct` changes.                                                                                                                                                  |
| hosting               | **Vercel**                                                | Zero-config Next.js deployment, edge middleware for auth checks, preview deploys for every PR.                                                                                                                                                       |
| secrets / encryption  | **App-layer AES-256-GCM via Node `crypto`**               | Connector credentials and SF tokens encrypted before INSERT, decrypted only in the worker at execution time. Master key in env var, rotatable.                                                                                                       |
| monitoring            | **Sentry + Trigger.dev dashboard**                        | Error tracking in the web app and in background jobs.                                                                                                                                                                                                |

> **One database. No microservices.** The web app and the worker queue share the same Postgres. The worker talks to Salesforce APIs, external connectors, and R2 — the web app never does heavy I/O directly.

---

## Schema

**Tables: 25.** Access rules: **data-layer authorization checks** (every query filtered by `org_id` from the session; Drizzle helper `withOrg(orgId)` wraps every query). RLS is a future hardening step.

Full SQL: [`schema.sql`](file:///d:/Claude/replica/schema.sql)

### Table inventory

| #   | table                 | purpose                                                                      | key indexes                                            |
| --- | --------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------ |
| 1   | `organizations`       | Tenant root — plan, quotas, billing                                          | PK                                                     |
| 2   | `users`               | Team members, linked to SF user via OAuth                                    | `org_id`, `email` unique                               |
| 3   | `salesforce_orgs`     | Connected SF environments (prod/sandbox) with encrypted tokens               | `(org_id, sf_org_id)` unique, `status`                 |
| 4   | `connectors`          | External source connections (S3/SFTP/DB/cloud) with encrypted config         | `org_id`                                               |
| 5   | `jobs`                | Import/export/migration configuration (the template)                         | `org_id`, `job_type`, `is_template` partial            |
| 6   | `job_objects`         | Objects within a multi-object job, with parent-child hierarchy               | `(job_id, load_order)`                                 |
| 7   | `field_mappings`      | Column → SF field mapping per object, with lookup resolution + formulas      | `(job_object_id, mapping_order)`                       |
| 8   | `transform_rules`     | Data transformation / filter / dedup rules per object                        | `(job_object_id, rule_order)`                          |
| 9   | `job_runs`            | Each execution of a job (with Bulk API job IDs, progress, worker assignment) | `(job_id, created_at)`, `status` partial for queue     |
| 10  | `job_run_records`     | Per-record outcomes (errors stored in DB, successes in R2 as gzipped CSV)    | `(job_run_id, status)`, `sf_record_id` partial         |
| 11  | `id_remap_cache`      | Magic ID: source → target record ID mapping during multi-object loads        | `(job_run_id, object, source_id)` unique               |
| 12  | `schedules`           | Cron-based recurring schedule per job                                        | `(job_id)` unique, `next_run_at` partial               |
| 13  | `flows`               | Multi-step data pipeline definition                                          | `org_id`                                               |
| 14  | `flow_steps`          | Each step in a flow, with error handling config                              | `(flow_id, step_order)`                                |
| 15  | `flow_runs`           | Execution of an entire flow                                                  | `(flow_id, created_at)`                                |
| 16  | `flow_step_runs`      | Per-step execution within a flow run                                         | `(flow_run_id, flow_step_id)`                          |
| 17  | `backup_policies`     | Automated backup configuration per SF org                                    | `(org_id, sf_org_id)`, `next_run_at` partial           |
| 18  | `backup_snapshots`    | Each daily backup run (full or incremental)                                  | `(policy_id, snapshot_date)` unique                    |
| 19  | `backup_records`      | Per-record change tracking in a snapshot (metadata in DB, payloads in R2)    | `(snapshot_id, object)`, `(snapshot_id, sf_record_id)` |
| 20  | `automation_controls` | SF automation toggle log (deactivate before / reactivate after)              | `job_run_id`                                           |
| 21  | `notifications`       | Alert preferences per org per event type                                     | `(org_id, event_type, channel)` unique                 |
| 22  | `uploaded_files`      | Temporarily stored CSV/Excel uploads (auto-expire 24h)                       | `org_id`, `expires_at` partial                         |
| 23  | `api_usage_log`       | Daily SF API call tracking per connected org                                 | `(sf_org_id, log_date)` unique                         |
| 24  | `audit_log`           | Immutable who-did-what log                                                   | `(org_id, created_at)`                                 |
| 25  | `flow_schedules`      | Optional cron schedule attached to a flow                                    | `(flow_id)` unique                                     |

### Critical constraints

1. **`id_remap_cache` unique index on `(job_run_id, sf_object_api_name, source_record_id)`** — ensures each source record maps to exactly one target record during multi-object loads. This is the "Magic ID" engine.
2. **`schedules` unique on `(job_id)`** — one schedule per job. Multiple schedules = multiple jobs (keeps scheduling atomic).
3. **`backup_snapshots` unique on `(policy_id, snapshot_date)`** — prevents duplicate daily snapshots.
4. **`job_runs` partial index on `status IN ('queued','running')`** — the worker polls only active runs.

---

## API

### Auth & Org Management

| method | path                            | does                                                        | who   | input                     | output               | flow    |
| ------ | ------------------------------- | ----------------------------------------------------------- | ----- | ------------------------- | -------------------- | ------- |
| GET    | `/api/auth/salesforce`          | Redirect to SF OAuth authorize endpoint                     | anon  | `org_type` (prod/sandbox) | 302 redirect         | F01-F14 |
| GET    | `/api/auth/salesforce/callback` | Exchange code for tokens, upsert user + SF org, set session | anon  | `code`, `state`           | 302 → `/dashboard`   | F01-F14 |
| POST   | `/api/auth/logout`              | Clear session                                               | user  | —                         | 200                  | —       |
| GET    | `/api/orgs`                     | List connected SF orgs for current organization             | user  | —                         | `SalesforceOrg[]`    | F01-F14 |
| POST   | `/api/orgs/connect`             | Start OAuth flow to add another SF org                      | admin | `org_type`                | 302 redirect         | F04,F05 |
| DELETE | `/api/orgs/:sfOrgId`            | Disconnect a SF org (revoke token)                          | admin | —                         | 200                  | —       |
| GET    | `/api/orgs/:sfOrgId/describe`   | Fetch org metadata: objects, fields, record types           | user  | `?object=Account`         | SF describe response | F01-F05 |
| GET    | `/api/orgs/:sfOrgId/limits`     | Fetch current API usage limits                              | user  | —                         | `{used, limit}`      | —       |

### Connectors

| method | path                       | does                                                   | who   | input                  | output         | flow    |
| ------ | -------------------------- | ------------------------------------------------------ | ----- | ---------------------- | -------------- | ------- |
| GET    | `/api/connectors`          | List saved connectors                                  | user  | —                      | `Connector[]`  | F02,F11 |
| POST   | `/api/connectors`          | Create a new connector (encrypt + store config)        | admin | `{type, name, config}` | `Connector`    | F11     |
| PUT    | `/api/connectors/:id`      | Update connector config                                | admin | `{name?, config?}`     | `Connector`    | F11     |
| POST   | `/api/connectors/:id/test` | Test connectivity (decrypt config, attempt connection) | user  | —                      | `{ok, error?}` | F11     |
| DELETE | `/api/connectors/:id`      | Delete connector and encrypted config                  | admin | —                      | 200            | F11     |

### Jobs (Import / Export / Migration)

| method | path                      | does                                                   | who   | input                                                    | output                    | flow            |
| ------ | ------------------------- | ------------------------------------------------------ | ----- | -------------------------------------------------------- | ------------------------- | --------------- |
| GET    | `/api/jobs`               | List all jobs/templates for the org                    | user  | `?type=import&template=true`                             | `Job[]`                   | F01-F06,F12,F13 |
| POST   | `/api/jobs`               | Create a new job configuration                         | user  | full job payload (source, objects, mappings, transforms) | `Job` with nested objects | F01-F05         |
| GET    | `/api/jobs/:id`           | Get full job config with objects, mappings, transforms | user  | —                                                        | `Job` (deep)              | F01-F14         |
| PUT    | `/api/jobs/:id`           | Update job configuration                               | user  | partial job payload                                      | `Job`                     | F01-F05         |
| POST   | `/api/jobs/:id/duplicate` | Clone a job as a new template                          | user  | `{name}`                                                 | `Job`                     | F05             |
| DELETE | `/api/jobs/:id`           | Delete job, cascades to objects/mappings/runs          | admin | —                                                        | 200                       | —               |

### File Upload

| method | path                     | does                                     | who  | input                 | output                               | flow        |
| ------ | ------------------------ | ---------------------------------------- | ---- | --------------------- | ------------------------------------ | ----------- |
| POST   | `/api/files/upload`      | Upload CSV/Excel to R2, parse headers    | user | multipart form (file) | `UploadedFile` with `parsed_headers` | F01,F03,F13 |
| GET    | `/api/files/:id/preview` | Preview first N rows of an uploaded file | user | `?rows=50`            | `{headers, rows}`                    | F01,F03     |
| DELETE | `/api/files/:id`         | Delete uploaded file from R2             | user | —                     | 200                                  | —           |

### Field Mapping

| method | path                                             | does                                           | who  | input                                       | output                 | flow        |
| ------ | ------------------------------------------------ | ---------------------------------------------- | ---- | ------------------------------------------- | ---------------------- | ----------- |
| POST   | `/api/jobs/:jobId/objects/:objId/auto-map`       | Auto-match source columns to SF fields by name | user | `{headers[], sfFields[]}`                   | `FieldMapping[]`       | F01-F05     |
| PUT    | `/api/jobs/:jobId/objects/:objId/mappings`       | Save field mappings (bulk upsert)              | user | `FieldMapping[]`                            | `FieldMapping[]`       | F01-F05     |
| POST   | `/api/jobs/:jobId/objects/:objId/lookup-resolve` | Test lookup resolution on sample records       | user | `{lookupField, matchField, sampleValues[]}` | `{matched, unmatched}` | F01,F03,F04 |

### Transform & Preview

| method | path                                         | does                                                   | who  | input              | output                     | flow    |
| ------ | -------------------------------------------- | ------------------------------------------------------ | ---- | ------------------ | -------------------------- | ------- |
| PUT    | `/api/jobs/:jobId/objects/:objId/transforms` | Save transform rules                                   | user | `TransformRule[]`  | `TransformRule[]`          | F01-F03 |
| POST   | `/api/jobs/:jobId/preview`                   | Run mappings + transforms on sample data, show preview | user | `{sampleSize: 50}` | `{rows, validationErrors}` | F01-F05 |

### Job Execution

| method | path                        | does                                                        | who  | input                                             | output             | flow                    |
| ------ | --------------------------- | ----------------------------------------------------------- | ---- | ------------------------------------------------- | ------------------ | ----------------------- | ---------- | ------- |
| POST   | `/api/jobs/:id/run`         | Enqueue a job run (creates `job_run`, dispatches to worker) | user | `{isSample?, sampleSize?, automationControls?[]}` | `JobRun`           | F01-F05,F12,F13         |
| GET    | `/api/runs/:runId`          | Get run status and progress                                 | user | —                                                 | `JobRun`           | F01-F14                 |
| GET    | `/api/runs/:runId/records`  | Paginated run records (success/error)                       | user | `?status=error&page=1&limit=50`                   | `{records, total}` | F01-F05                 |
| POST   | `/api/runs/:runId/retry`    | Retry failed records from a run                             | user | —                                                 | `JobRun` (new)     | F01-F03                 |
| POST   | `/api/runs/:runId/cancel`   | Cancel a running job (abort Bulk API jobs)                  | user | —                                                 | `JobRun`           | F01-F05                 |
| POST   | `/api/runs/:runId/rollback` | Rollback: delete inserts or revert updates                  | user | `{scope: 'all'                                    | recordIds[]}`      | `JobRun` (rollback run) | F09        |
| GET    | `/api/runs/:runId/download` | Download results or errors as CSV                           | user | `?type=success                                    | errors             | all`                    | CSV stream | F01-F05 |

### Scheduling

| method | path                            | does                      | who  | input                                              | output            | flow |
| ------ | ------------------------------- | ------------------------- | ---- | -------------------------------------------------- | ----------------- | ---- |
| GET    | `/api/jobs/:id/schedule`        | Get schedule for a job    | user | —                                                  | `Schedule` or 404 | F06  |
| PUT    | `/api/jobs/:id/schedule`        | Create or update schedule | user | `{frequency, cron, timezone, startDate, endDate?}` | `Schedule`        | F06  |
| DELETE | `/api/jobs/:id/schedule`        | Remove schedule           | user | —                                                  | 200               | F06  |
| PATCH  | `/api/jobs/:id/schedule/toggle` | Enable/disable schedule   | user | `{isActive}`                                       | `Schedule`        | F06  |

### Flows

| method | path                      | does                                   | who   | input               | output           | flow |
| ------ | ------------------------- | -------------------------------------- | ----- | ------------------- | ---------------- | ---- |
| GET    | `/api/flows`              | List flows for the org                 | user  | —                   | `Flow[]`         | F10  |
| POST   | `/api/flows`              | Create a flow with steps               | user  | `{name, steps[]}`   | `Flow` (deep)    | F10  |
| PUT    | `/api/flows/:id`          | Update flow steps and config           | user  | `{name?, steps?[]}` | `Flow`           | F10  |
| POST   | `/api/flows/:id/run`      | Enqueue a flow run                     | user  | —                   | `FlowRun`        | F10  |
| GET    | `/api/flow-runs/:runId`   | Get flow run status with step statuses | user  | —                   | `FlowRun` (deep) | F10  |
| DELETE | `/api/flows/:id`          | Delete flow                            | admin | —                   | 200              | —    |
| PUT    | `/api/flows/:id/schedule` | Set flow schedule                      | user  | `{cron, timezone}`  | `FlowSchedule`   | F10  |

### Backups

| method | path                                  | does                                                   | who   | input                                                              | output                         | flow                   |
| ------ | ------------------------------------- | ------------------------------------------------------ | ----- | ------------------------------------------------------------------ | ------------------------------ | ---------------------- | --- |
| GET    | `/api/backups/policies`               | List backup policies                                   | user  | —                                                                  | `BackupPolicy[]`               | F07                    |
| POST   | `/api/backups/policies`               | Create backup policy                                   | admin | `{sfOrgId, name, objects[], retention, compression, includeFiles}` | `BackupPolicy`                 | F07                    |
| PUT    | `/api/backups/policies/:id`           | Update backup policy                                   | admin | partial payload                                                    | `BackupPolicy`                 | F07                    |
| PATCH  | `/api/backups/policies/:id/toggle`    | Activate/deactivate policy                             | admin | `{isActive}`                                                       | `BackupPolicy`                 | F07                    |
| DELETE | `/api/backups/policies/:id`           | Delete policy (keeps existing snapshots per retention) | admin | —                                                                  | 200                            | —                      |
| GET    | `/api/backups/policies/:id/snapshots` | List snapshots for a policy                            | user  | `?page=1&limit=30`                                                 | `{snapshots, total}`           | F08                    |
| GET    | `/api/backups/snapshots/:id`          | Snapshot detail with delta counts per object           | user  | —                                                                  | `BackupSnapshot` (deep)        | F08                    |
| GET    | `/api/backups/snapshots/:id/records`  | Browse records in a snapshot                           | user  | `?object=Account&changeType=update&page=1`                         | `{records, total}`             | F08                    |
| POST   | `/api/backups/snapshots/:id/compare`  | Side-by-side field comparison for specific records     | user  | `{sfRecordIds[]}`                                                  | `{records: [{before, after}]}` | F08                    |
| POST   | `/api/backups/snapshots/:id/restore`  | Restore selected records from snapshot                 | user  | `{sfRecordIds[]                                                    | all, objects?[]}`              | `JobRun` (restore run) | F08 |
| GET    | `/api/backups/storage`                | Current storage usage vs quota                         | user  | —                                                                  | `{used, quota, breakdown[]}`   | F07                    |

### Automation Control

| method | path                                  | does                                                    | who  | input                        | output                | flow |
| ------ | ------------------------------------- | ------------------------------------------------------- | ---- | ---------------------------- | --------------------- | ---- |
| GET    | `/api/orgs/:sfOrgId/automations`      | List Flows, Triggers, Validation Rules via Metadata API | user | `?type=flow`                 | `{automations[]}`     | F04  |
| POST   | `/api/runs/:runId/automations/toggle` | Deactivate selected automations before run              | user | `{items: [{type, apiName}]}` | `AutomationControl[]` | F04  |

### Team & Settings

| method | path                     | does                            | who   | input               | output             | flow |
| ------ | ------------------------ | ------------------------------- | ----- | ------------------- | ------------------ | ---- |
| GET    | `/api/team`              | List team members               | admin | —                   | `User[]`           | —    |
| POST   | `/api/team/invite`       | Invite user by email            | admin | `{email, role}`     | `User` (pending)   | —    |
| PUT    | `/api/team/:userId/role` | Change user role                | admin | `{role}`            | `User`             | —    |
| DELETE | `/api/team/:userId`      | Remove user from org            | admin | —                   | 200                | —    |
| GET    | `/api/notifications`     | Get notification preferences    | user  | —                   | `Notification[]`   | —    |
| PUT    | `/api/notifications`     | Update notification preferences | admin | `Notification[]`    | `Notification[]`   | —    |
| GET    | `/api/api-usage`         | API usage log (daily breakdown) | user  | `?sfOrgId=&days=30` | `ApiUsageLog[]`    | —    |
| GET    | `/api/audit-log`         | Audit log (paginated)           | admin | `?page=1&limit=50`  | `{entries, total}` | —    |

### Webhooks out (from our platform)

None required initially — notifications go via email (Resend). Future: webhook channel for `notifications` table.

### Background Jobs (Trigger.dev)

| job name            | trigger                                                     | what it does                                                                                                                                                                                                                                                                       |
| ------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `job.execute`       | on-demand (from `/api/jobs/:id/run`)                        | Orchestrates the full import/export/migration: decrypt credentials → fetch source data → parse/transform → Bulk API 2.0 batches → record results → update `job_runs` → trigger notifications. For multi-object: processes parent first, populates `id_remap_cache`, then children. |
| `job.retry`         | on-demand (from `/api/runs/:runId/retry`)                   | Re-runs only error records from a previous run.                                                                                                                                                                                                                                    |
| `job.rollback`      | on-demand (from `/api/runs/:runId/rollback`)                | For inserts: deletes created records. For updates: reverts to `original_values` from `job_run_records`.                                                                                                                                                                            |
| `backup.snapshot`   | cron (daily per policy, from `backup_policies.next_run_at`) | Queries SF org for all records in policy objects. First run = full snapshot. Subsequent = incremental delta (compare `SystemModstamp`). Compress to gzip, store in R2, write deltas to `backup_records`.                                                                           |
| `backup.restore`    | on-demand (from `/api/backups/snapshots/:id/restore`)       | Reads snapshot data from R2, upserts/inserts/undeletes records in target SF org.                                                                                                                                                                                                   |
| `backup.cleanup`    | cron daily at 02:00 UTC                                     | Deletes expired snapshots and R2 objects beyond `retention_days`.                                                                                                                                                                                                                  |
| `schedule.poll`     | cron every 1 minute                                         | Queries `schedules` and `flow_schedules` where `next_run_at <= now()` and `is_active = true`. Enqueues `job.execute` or `flow.execute`. Updates `next_run_at`.                                                                                                                     |
| `flow.execute`      | on-demand (from `/api/flows/:id/run` or `schedule.poll`)    | Executes flow steps in order. For each step: enqueue `job.execute`, wait for completion, check `on_error` policy, proceed or stop. Updates `flow_runs` and `flow_step_runs`.                                                                                                       |
| `automation.toggle` | sub-task of `job.execute`                                   | Before job: read Metadata API, deactivate selected items. After job: reactivate. Log to `automation_controls`.                                                                                                                                                                     |
| `file.cleanup`      | cron hourly                                                 | Deletes uploaded files past `expires_at` from R2 and DB.                                                                                                                                                                                                                           |
| `api-usage.sync`    | cron daily at 00:30 UTC                                     | Fetches `/services/data/vXX.0/limits` from each connected SF org, writes to `api_usage_log`.                                                                                                                                                                                       |
| `notification.send` | event-driven (from other jobs)                              | Sends email via Resend when a job succeeds, fails, or a schedule is missed.                                                                                                                                                                                                        |

---

## Salesforce API Integration Design

### OAuth 2.0 (Web Server Flow)

```
1. User clicks "Connect Org" → redirect to:
   https://login.salesforce.com/services/oauth2/authorize
   ?response_type=code
   &client_id={CONNECTED_APP_KEY}
   &redirect_uri={CALLBACK_URL}
   &scope=api refresh_token web
   &state={encrypted_session_state}

   For sandboxes: https://test.salesforce.com/...

2. Callback receives `code` → POST to /services/oauth2/token
   → receives access_token, refresh_token, instance_url, id (user info URL)

3. Fetch user identity from `id` URL → upsert User + SalesforceOrg
4. Encrypt tokens with AES-256-GCM → store in `salesforce_orgs`
5. Set session cookie via iron-session
```

**Token refresh:** Before every SF API call in workers, check `token_expires_at`. If expired or within 5 minutes, POST to `/services/oauth2/token` with `grant_type=refresh_token`. Update stored token. Mutex lock (Postgres advisory lock by `sf_org_id`) prevents concurrent refresh races.

### Bulk API 2.0 (for imports ≥200 records)

```
Insert/Update/Upsert flow:
1. POST /services/data/v62.0/jobs/ingest
   {object, operation, contentType: "CSV", lineEnding: "LF"}
   → returns jobId

2. PUT /services/data/v62.0/jobs/ingest/{jobId}/batches
   Content-Type: text/csv
   Body: CSV data (up to 150 MB per request, 100M chars)

3. PATCH /services/data/v62.0/jobs/ingest/{jobId}
   {state: "UploadComplete"}

4. Poll GET /services/data/v62.0/jobs/ingest/{jobId}
   until state = "JobComplete" or "Failed"
   (poll interval: 5s → 10s → 30s exponential backoff)

5. GET /services/data/v62.0/jobs/ingest/{jobId}/successfulResults
   GET /services/data/v62.0/jobs/ingest/{jobId}/failedResults
   → parse CSV results, write to job_run_records
```

**For <200 records:** Use REST API composite requests (`/services/data/v62.0/composite/sobjects`) for lower latency — batch up to 200 records per request.

### REST API (for describe, query, single-record ops)

- **Describe:** `GET /services/data/v62.0/sobjects/{object}/describe` → cache for 1 hour per org+object.
- **SOQL query:** `GET /services/data/v62.0/query/?q={SOQL}` → for exports, migration source reads, backup deltas.
- **Query more:** follow `nextRecordsUrl` for pagination.

### Metadata API (for automation control)

```
1. List automations:
   GET /services/data/v62.0/tooling/query
   ?q=SELECT Id,FullName,Status FROM Flow WHERE Status='Active'

2. Deactivate:
   PATCH /services/data/v62.0/tooling/sobjects/Flow/{id}
   {Metadata: {status: "Draft"}}

3. Reactivate (after job):
   PATCH /services/data/v62.0/tooling/sobjects/Flow/{id}
   {Metadata: {status: "Active"}}
```

---

## Multi-Object Relationship Resolution ("Magic ID")

This is the hardest algorithmic piece. Here's how it works:

```
Input: Job with objects [Account (parent), Contact (child)]
       Contact has lookup field AccountId → Account

Phase 1 — Topological Sort:
  - Build dependency graph from job_objects parent-child relationships
  - Sort: Account (order 0) → Contact (order 1)
  - Circular dependency? Error at job creation time.

Phase 2 — Process parent (Account):
  For each record batch:
    1. Apply transforms and formulas
    2. Bulk API insert/upsert → get back {sf:Id, source:row_number}
    3. Write to id_remap_cache:
       {job_run_id, 'Account', source_row_1, '001xx000003DGbY'}

Phase 3 — Process child (Contact):
  For each record batch:
    1. Apply transforms and formulas
    2. For each lookup field (AccountId):
       a. Read the source value (Account name, external ID, or row ref)
       b. Query id_remap_cache for matching target ID
       c. Replace source value with remapped SF ID
    3. Bulk API insert/upsert with resolved IDs

Phase 4 — Verify:
  Check for unresolved lookups → report as errors in job_run_records
```

**For org-to-org migration:** Source records already have SF IDs. The remap maps old source-org IDs to new target-org IDs. Same algorithm, the source value is the 15/18-char SF ID from the source org's query result.

---

## Backup & Snapshot Architecture

```
                  ┌─────────────────────────────────────────┐
                  │            Trigger.dev Worker            │
                  │                                          │
                  │  backup.snapshot job (daily cron)         │
                  │  1. Query SF: SOQL with SystemModstamp   │
                  │     > last_snapshot_date                  │
                  │  2. Diff against previous snapshot        │
                  │  3. Classify: insert / update / delete    │
                  │  4. Gzip JSONL per object                 │
                  │  5. Upload to R2:                         │
                  │     backups/{orgId}/{date}/{object}.jsonl.gz│
                  │  6. Write metadata to backup_snapshots   │
                  │     and backup_records (summary rows)     │
                  └──────────┬───────────────────────────────┘
                             │
                  ┌──────────▼───────────────────────────────┐
                  │          Cloudflare R2                     │
                  │                                           │
                  │  /backups/{orgId}/{date}/                  │
                  │    Account.jsonl.gz                        │
                  │    Contact.jsonl.gz                        │
                  │    ContentVersion.jsonl.gz                 │
                  │    _manifest.json (object list, counts)    │
                  └───────────────────────────────────────────┘

Restore flow:
  1. User selects snapshot + records (or all)
  2. Worker downloads .jsonl.gz from R2
  3. Decompresses, filters to target records
  4. Upserts into SF org via Bulk API 2.0
  5. For deletes: undelete via REST API
  6. Logs to job_run_records

Delta detection:
  - Full backup: query ALL records with all fields, store to R2
  - Incremental: query WHERE SystemModstamp > {last_snapshot_date}
  - Detect deletes: query getDeleted() REST endpoint for the date range
  - Store delta counts in backup_snapshots (inserts_delta, etc.)
```

---

## The parts that bite

### Salesforce API rate limits

Salesforce enforces per-org daily API call limits (varies by edition: 15,000 for Professional, 100,000 for Enterprise, 1,000,000 for Unlimited). Our worker must track `api_usage_log` and refuse to start a job if the remaining budget is <10% of estimated calls. Bulk API 2.0 has separate limits (15,000 Bulk API batches/day) — use it for >200 records to minimize REST call consumption. Cache `describe` results aggressively (1 hour TTL).

### Token refresh races

Multiple workers might try to refresh the same SF token simultaneously. Use a Postgres advisory lock `pg_advisory_xact_lock(hashtext(sf_org_id))` before the refresh. The winning worker writes the new token; losers re-read from DB.

### Idempotency

- **Bulk API jobs are not idempotent for inserts.** If the worker crashes after uploading CSV but before recording results, we could double-insert. Mitigation: store Bulk API job IDs in `job_runs.sf_bulk_job_ids` _before_ uploading. On retry, check Bulk API job status first — if `JobComplete`, fetch results instead of re-uploading.
- **Schedule poll:** `schedule.poll` could fire twice. Use `UPDATE schedules SET last_run_at = now(), next_run_at = {next} WHERE id = ? AND next_run_at <= now() RETURNING *` — the atomic UPDATE-RETURNING acts as a lock. Only one poller wins the row.

### Multi-object ordering and partial failures

If parent insert succeeds but child insert fails, the parent records are already in Salesforce. The user sees partial success. Rollback must handle this: rolling back a multi-object run deletes children first (reverse load order), then parents. The `id_remap_cache` drives the reverse cascade.

### Large file handling

CSVs can be hundreds of MBs. Never load the entire file into memory. Use Node.js streams:

1. Upload: stream from browser → R2 (presigned URL PUT)
2. Parse: stream from R2 → `csv-parse` (streaming) → transform → batch into 10K-row chunks → Bulk API
3. Worker memory target: <512 MB per job execution.

### Time zones & scheduling

Cron expressions are stored alongside an IANA timezone. `schedule.poll` converts `next_run_at` to UTC for comparison. Use `luxon` or `date-fns-tz` for DST-safe cron calculations. Never use UTC offset — it doesn't handle DST transitions.

### Connector credential security

All connector configs (S3 keys, SFTP passwords, DB connection strings) and SF tokens are encrypted at the application layer with AES-256-GCM. The encryption key (32 bytes) lives in `process.env.ENCRYPTION_KEY`, loaded only in the worker. The web app _never_ decrypts credentials — it only stores and retrieves the ciphertext. Key rotation: re-encrypt all rows with the new key in a migration, keep the old key in `ENCRYPTION_KEY_PREVIOUS` for a grace period.

### SFTP file matching

SFTP sources support wildcard patterns (e.g., `Account_Import_*.csv`). After processing, rename the file on the SFTP server (append `.processed`) to prevent re-importing. If rename fails, log a warning but don't fail the job — track last-processed filename in `source_config.last_processed_file`.

### Backup storage costs

Gzipped JSONL reduces storage 5-10×. With 365-day retention and large orgs (millions of records), storage can still reach tens of GB. The `backup.cleanup` job enforces `retention_days` strictly. The `organizations.storage_quota_bytes` column enforces per-org caps. Alert at 80% via `api_limit_warning` notification.

### Metadata API version pinning

Salesforce releases 3 API versions per year. Pin to a specific version (e.g., v62.0) in env config. Test against new versions each Salesforce release. The `describe` cache must be invalidated when switching API versions.

### Multi-tenancy isolation

Every query includes `WHERE org_id = {session.orgId}`. The Drizzle helper `withOrg(orgId)` is a mandatory wrapper — no query escapes it. The audit log is immutable (no UPDATE or DELETE). Background jobs receive `orgId` as a parameter and re-validate before executing.

### GDPR / data deletion

When an org is deleted, cascade delete removes all data. R2 objects (uploaded files, backup snapshots) must be cleaned up asynchronously — a `org.cleanup` background job walks the R2 prefix `{orgId}/` and deletes everything. Provide a data export endpoint before deletion.

---

## Build order

### Milestone 1 — Vertical Slice: CSV import end-to-end (proves the stack)

**Screens:** S02, S03, S05, S06, S07, S08, S10, S11, S12
**Tables:** `organizations`, `users`, `salesforce_orgs`, `jobs`, `job_objects`, `field_mappings`, `job_runs`, `job_run_records`, `uploaded_files`
**Routes:** auth (OAuth + callback), `POST /api/files/upload`, `GET /api/files/:id/preview`, `POST /api/jobs`, `POST /api/jobs/:id/objects/:objId/auto-map`, `POST /api/jobs/:id/preview`, `POST /api/jobs/:id/run`, `GET /api/runs/:runId`, `GET /api/runs/:runId/records`
**Worker jobs:** `job.execute` (CSV → Bulk API 2.0 → results)
**Goal:** A user logs in with Salesforce, uploads a CSV, maps columns, previews, and imports into their org. They see real-time progress and results with error details.

### Milestone 2 — Must-haves: core data loading

**Screens:** S08 (lookup resolution), S09, S13, S14, S15, S16
**Tables:** `transform_rules`, `id_remap_cache`
**Routes:** lookup-resolve, transforms CRUD, retry, rollback, download CSV, jobs list
**Worker jobs:** `job.retry`, `job.rollback`
**Features:** Excel import, manual mapping, lookup field resolution, formulas/transforms, dedup, preview with validation, error retry, rollback of inserts, save as template, job list/search.

### Milestone 3 — Must-haves: multi-object + migration

**Screens:** S07 (multi-object), S17, S18, S19, S20
**Tables:** (uses existing, adds parent-child to `job_objects`)
**Routes:** org describe, migration-specific job creation
**Worker jobs:** `job.execute` extended for topological sort + `id_remap_cache` population
**Features:** Multi-object parent-child import with ID remapping ("Magic ID"), Salesforce-to-Salesforce migration, reusable migration templates, SOQL filters, file/attachment migration (ContentVersion).

### Milestone 4 — Must-haves: backup & rollback

**Screens:** S23, S24, S25, S26
**Tables:** `backup_policies`, `backup_snapshots`, `backup_records`
**Routes:** full backup API (policies, snapshots, records, compare, restore, storage)
**Worker jobs:** `backup.snapshot`, `backup.restore`, `backup.cleanup`
**Features:** Automated daily backups, incremental delta tracking, gzip compression, record-level rollback from snapshot, pre-import snapshots, field-level before/after comparison, storage usage tracking.

### Milestone 5 — Should-haves: connectors + scheduling

**Screens:** S22, S27
**Tables:** `connectors`, `schedules`
**Routes:** connectors CRUD + test, schedule CRUD + toggle
**Worker jobs:** `schedule.poll`
**Features:** S3, SFTP, PostgreSQL, Google Drive, Google Sheets, SharePoint, Snowflake, Azure SQL connectors. Job scheduling (15min to custom cron) with timezone support.

### Milestone 6 — Should-haves: remaining backup + transforms

**Screens:** S29
**Tables:** `api_usage_log`
**Routes:** API usage, enhanced backup
**Worker jobs:** `api-usage.sync`
**Features:** Backup retention configuration, ContentVersion backup, pre-import snapshot toggle, API usage monitoring, inline formula enhancements, row-level filters.

### Milestone 7 — Could-haves: flows, automation, team

**Screens:** S21, S28, S30, S32
**Tables:** `flows`, `flow_steps`, `flow_runs`, `flow_step_runs`, `flow_schedules`, `automation_controls`, `notifications`, `audit_log`
**Routes:** flows CRUD + run, automation toggle, team management, notifications, audit log
**Worker jobs:** `flow.execute`, `automation.toggle`, `notification.send`
**Features:** Multi-step flows/pipelines with error handling, automation control (deactivate SF flows/triggers), team management with roles, email notifications, export to CSV/connector, sandbox seeding, audit log.

### Milestone 8 — Fixes from replica-entrepreneur

**After** `/replica-entrepreneur` runs and identifies gaps / user pain points.

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Vercel Edge                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Next.js 15 App Router                       │  │
│  │                                                               │  │
│  │  /app/(auth)/login      → Salesforce OAuth redirect           │  │
│  │  /app/(app)/dashboard   → Server Component (RSC)              │  │
│  │  /app/(app)/jobs/new    → Multi-step wizard (Client + RSC)    │  │
│  │  /app/(app)/backups     → Server Component (RSC)              │  │
│  │  /app/(app)/flows       → Client Component (drag & drop)      │  │
│  │  /app/api/...           → Route Handlers (REST API)           │  │
│  └──────────────────────┬──────────────────────────────────┬─────┘  │
│                         │                                  │        │
│              ┌──────────▼──────────┐           ┌──────────▼──────┐ │
│              │   Drizzle ORM       │           │  iron-session    │ │
│              │   (data layer)      │           │  (auth cookie)   │ │
│              └──────────┬──────────┘           └─────────────────┘ │
└─────────────────────────┼───────────────────────────────────────────┘
                          │
              ┌───────────▼───────────┐
              │   Supabase Postgres   │
              │   (25 tables)         │
              │   + Realtime          │
              │     (job progress)    │
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │   Trigger.dev v3      │
              │   Worker Pool         │◄──── cron: schedule.poll (1min)
              │                       │◄──── cron: backup.snapshot (daily)
              │   • job.execute       │◄──── cron: backup.cleanup (daily)
              │   • job.retry         │◄──── cron: file.cleanup (hourly)
              │   • job.rollback      │◄──── cron: api-usage.sync (daily)
              │   • backup.snapshot   │
              │   • backup.restore    │
              │   • flow.execute      │
              │   • automation.toggle │
              │   • notification.send │
              └──┬────────┬───────┬───┘
                 │        │       │
     ┌───────────▼──┐  ┌──▼───┐  ┌▼──────────────────────┐
     │ Salesforce    │  │  R2  │  │ External Connectors    │
     │ Orgs (target) │  │      │  │                        │
     │               │  │ CSVs │  │  • Amazon S3           │
     │ • Bulk API    │  │ Back │  │  • SFTP servers        │
     │   2.0         │  │ ups  │  │  • PostgreSQL          │
     │ • REST API    │  │ Snap │  │  • Google Drive/Sheets │
     │ • Metadata    │  │ shots│  │  • SharePoint          │
     │   API         │  │      │  │  • Snowflake           │
     │ • Tooling     │  └──────┘  │  • Azure SQL           │
     │   API         │            └────────────────────────┘
     └───────────────┘
              │
     ┌────────▼───────┐
     │ Resend (email) │
     │ notifications  │
     └────────────────┘
```

---

## Summary

**Stack in one line:** Next.js 15 + Drizzle + Supabase Postgres + Trigger.dev workers + Cloudflare R2 + Salesforce OAuth/Bulk API 2.0.

**Counts:** 25 tables, ~65 API routes, 11 background jobs, 7 build milestones.

**Three riskiest parts:**

1. **Salesforce Bulk API 2.0 orchestration** — idempotency across crashes, rate limit tracking, 150MB CSV chunking, exponential backoff polling
2. **Multi-object ID remapping ("Magic ID")** — topological sort of object dependencies, concurrent remap cache population, partial failure rollback in reverse order
3. **Incremental backup delta tracking** — `SystemModstamp`-based change detection, `getDeleted()` for hard deletes, gzipped JSONL storage with 365-day retention, surgical record-level restore

**Next step:** `/replica-design` to build the design system — tokens, components, and screen layouts.
