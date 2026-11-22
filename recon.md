# Recon map: Dataimporter.io (Web — Salesforce-hosted SaaS)

Scope: Full product — data loading (CSV/Excel/S3/SFTP/DB/cloud), multi-object imports, Salesforce-to-Salesforce migration, automated backups with rollback, job scheduling, flows, and partner/ISV features.
For: Building a competing Salesforce data-management platform.
Date: 2026-11-22

---

## Sources

| #   | source               | URL                                                        | notes                                               |
| --- | -------------------- | ---------------------------------------------------------- | --------------------------------------------------- |
| 1   | marketing site       | https://dataimporter.io                                    | positioning, feature list, pricing CTA              |
| 2   | help center / docs   | https://app.dataimporter.io (resource portal)              | step-by-step guides, connector setup, API usage     |
| 3   | pricing page         | https://dataimporter.io (pricing section)                  | Free / Premium / Enterprise / Partner tiers         |
| 4   | AppExchange listing  | https://appexchange.salesforce.com (search "Dataimporter") | screenshots, ratings, reviews, editions             |
| 5   | changelog            | https://dataimporter.io (changelog / blog)                 | backup launch Feb 2026, delta tracking, compression |
| 6   | Salesforce community | https://appexchange.salesforce.com                         | user reviews and feedback                           |

---

## Core loop

**Users connect a Salesforce org, pick a data source (file, cloud storage, database, or another Salesforce org), map columns to Salesforce fields, preview/sample, run the job, and optionally schedule it to recur — with automated backup snapshots and one-click rollback if anything goes wrong.**

---

## Screens

| ID  | screen                              | route / how to reach                | purpose                                                                | key components                                                                                                                                                               | states seen                                                              |
| --- | ----------------------------------- | ----------------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| S01 | Landing / marketing page            | `/`                                 | Product positioning, feature overview, CTA to sign up or log in        | Hero section, feature cards, pricing toggle, testimonials, CTA buttons                                                                                                       | default                                                                  |
| S02 | Sign-up / Login                     | `/login` or OAuth redirect          | Authenticate via Salesforce OAuth                                      | OAuth button, Salesforce org selector                                                                                                                                        | logged-out, OAuth flow, error (token expired)                            |
| S03 | Dashboard / Home                    | `/dashboard` or `/home`             | Overview of recent jobs, connected orgs, quick actions                 | Job list table, org selector dropdown, quick-action cards (New Import, New Migration, New Backup), notification bell                                                         | empty (no jobs), populated, notifications present                        |
| S04 | Org connection manager              | Settings → Connected Orgs           | Add/remove Salesforce orgs, view connection status                     | Org list with status badges, "Connect Org" button (triggers OAuth), disconnect/reconnect actions                                                                             | no orgs, one+ orgs, connection error, sandbox vs production labels       |
| S05 | New job wizard — Source selection   | New Import → Step 1                 | Choose data source type                                                | Source-type cards (CSV/Excel upload, S3, SFTP, Google Drive, Google Sheets, SharePoint, Snowflake, Azure SQL, PostgreSQL, Heroku Postgres, Salesforce Org)                   | default selection grid                                                   |
| S06 | New job wizard — Source config      | New Import → Step 2                 | Configure source connection details                                    | File upload dropzone (CSV/Excel), S3 bucket/key inputs, SFTP host/port/credentials, DB connection string + SQL query editor, Google/SharePoint OAuth, Salesforce SOQL editor | varies per source type; file uploaded, connection test pass/fail         |
| S07 | New job wizard — Object & operation | New Import → Step 3                 | Pick target Salesforce object(s) and operation type                    | Object picker (searchable, standard + custom objects), operation radio buttons (Insert / Update / Upsert / Delete / Export), multi-object add button                         | single object, multi-object tree                                         |
| S08 | New job wizard — Field mapping      | New Import → Step 4                 | Map source columns to Salesforce fields                                | Two-column mapping table (source → target), auto-match toggle, lookup field resolver config, formula editor inline, drag-to-reorder                                          | auto-mapped, manually adjusted, unmapped fields warning, formula applied |
| S09 | New job wizard — Transformations    | New Import → Step 4b (or sub-panel) | Apply data transformations and filters                                 | Formula bar (IF, ISNULL, CONTAINS, CONCAT, SPLIT, REPLACE), filter rule builder, SQL WHERE clause editor (for DB sources), deduplication rules                               | no transforms, one+ transforms, filter active                            |
| S10 | New job wizard — Preview / Sample   | New Import → Step 5                 | Preview mapped data before full run                                    | Data preview table (paginated, ~first 10–50 rows), field-level validation indicators, sample-run button, record count                                                        | preview loaded, sample run results, validation errors                    |
| S11 | Job execution — Progress            | Running job                         | Show real-time progress of a running job                               | Progress bar, records processed / failed / total counters, elapsed time, cancel button, live log stream                                                                      | running, paused, completed, failed, cancelled                            |
| S12 | Job results — Summary               | Job detail → Results                | View completed job results                                             | Success/failure counts, error log table (row-level errors with Salesforce error codes), download CSV of results, rollback button                                             | all success, partial failures, all failed                                |
| S13 | Job results — Successful records    | Job detail → Successful             | Browse successfully loaded records                                     | Paginated record table with Salesforce IDs, rollback (delete inserted) button                                                                                                | populated, empty                                                         |
| S14 | Job results — Error records         | Job detail → Errors                 | Browse and retry failed records                                        | Error table (row #, field, Salesforce error code, message), retry button, download errors CSV                                                                                | errors present, no errors                                                |
| S15 | Rollback confirmation               | Job results → Rollback              | Confirm and execute rollback of a job                                  | Confirmation modal with record count, rollback scope (insert → delete, update → revert), execute/cancel                                                                      | confirmation pending, rollback in progress, rollback complete            |
| S16 | Saved jobs / Templates list         | Jobs / Templates nav                | Browse all saved jobs and reusable templates                           | Job list table (name, source, target object, operation, schedule, last run, status), search/filter, create/duplicate/delete actions                                          | empty, populated, filtered                                               |
| S17 | Migration wizard — Source org       | New Migration → Step 1              | Select source Salesforce org                                           | Connected org dropdown, SOQL filter builder, object hierarchy tree                                                                                                           | org selected, filters applied                                            |
| S18 | Migration wizard — Target org       | New Migration → Step 2              | Select target Salesforce org                                           | Connected org dropdown, field mapping (auto-mapped with "Magic ID" for relationship resolution)                                                                              | org selected, auto-mapped                                                |
| S19 | Migration wizard — Object hierarchy | New Migration → Step 3              | Define parent-child object loading order                               | Drag-and-drop hierarchy tree, add/remove objects, SOQL filters per object, file/attachment toggle                                                                            | tree built, single object, complex hierarchy                             |
| S20 | Migration wizard — Preview & run    | New Migration → Step 4              | Preview migration, test run, full run                                  | Record count per object, test-run button, full-run button, automation control toggle panel                                                                                   | preview loaded, test run complete                                        |
| S21 | Automation control panel            | Inside job/migration wizard         | Toggle Salesforce Flows/Triggers/Validation Rules on/off during import | Checklist of Salesforce automations (by Metadata API name), toggle switches (deactivate before / reactivate after), org scope                                                | automations listed, some toggled off, all active                         |
| S22 | Scheduling config                   | Job detail → Schedule tab           | Set up recurring job schedules                                         | Frequency picker (every 15 min, hourly, daily, weekly, custom cron), time zone selector, start/end date, enable/disable toggle                                               | no schedule, schedule active, schedule paused                            |
| S23 | Backup dashboard                    | Backup nav section                  | Overview of backup policies, storage usage, last run                   | Backup policy list, storage usage bar, object coverage summary, last-run timestamps                                                                                          | no policies, policies active, storage nearing limit                      |
| S24 | Backup policy config                | New Backup / Edit Backup            | Configure backup policy for specific objects                           | Object multi-select, frequency (daily), retention period slider (up to 365 days), include Files/ContentVersion toggle, compression (gzip) toggle                             | new policy, existing policy                                              |
| S25 | Backup history / Snapshots          | Backup → History                    | Browse backup snapshots over time                                      | Timeline or calendar view of daily snapshots, per-object record counts, delta changes (inserts/updates/deletes), download snapshot                                           | timeline populated, single snapshot detail                               |
| S26 | Backup restore / Rollback           | Backup → Restore                    | Restore specific records from a backup snapshot                        | Snapshot selector, object filter, record-level search, field comparison (before/after), selective restore button                                                             | snapshot selected, records previewed, restore in progress                |
| S27 | Connector settings                  | Settings → Connectors               | Configure external source connections (S3, SFTP, DB, cloud)            | Connector list (type, name, status), add/edit/test/delete per connector, credential fields                                                                                   | no connectors, one+, connection test pass/fail                           |
| S28 | Team / User management              | Settings → Team                     | Manage users and permissions                                           | User list (name, email, role), invite button, role selector (Admin, User), remove user                                                                                       | single user, team, pending invites                                       |
| S29 | API usage monitor                   | Settings → API Usage                | Track Salesforce API call consumption                                  | API calls used vs. limit bar chart, per-job breakdown, daily trend chart                                                                                                     | under limit, approaching limit, over limit warning                       |
| S30 | Notification / Alert settings       | Settings → Notifications            | Configure email alerts for job success/failure                         | Notification toggle per event type (job success, job failure, schedule missed, backup complete), email recipients list                                                       | defaults, customized                                                     |
| S31 | Partner / ISV admin                 | Settings → Partner                  | Manage locked templates, customer org access, ISV controls             | Customer org list, locked template toggle, template sharing controls, usage analytics                                                                                        | partner mode active                                                      |
| S32 | Flows builder                       | Flows nav section                   | Chain multiple jobs into a sequential data pipeline                    | Flow canvas or step list (Job 1 → Job 2 → Job 3), add/remove/reorder steps, conditional branching, error handling (stop/skip/retry), schedule                                | empty flow, multi-step flow, flow with error                             |

---

## Flows

```
F01 Import CSV/Excel into Salesforce
    S02 login -> S03 dashboard -> S05 source (CSV/Excel) -> S06 upload file ->
    S07 pick object + operation -> S08 map fields -> S09 transforms (optional) ->
    S10 preview/sample -> S11 run -> S12 results
    happy path clicks: 8
    edge: bad file format, unmapped required fields, duplicate records,
          Salesforce validation rule errors, governor limits hit

F02 Import from cloud/external source (S3/SFTP/DB/Google/SharePoint/Snowflake)
    S02 login -> S03 dashboard -> S05 source (choose connector) ->
    S06 configure connection (or select saved connector) -> S07 pick object ->
    S08 map fields -> S09 transforms + SQL filter -> S10 preview -> S11 run -> S12 results
    happy path clicks: 9
    edge: connection refused, auth expired, SQL syntax error,
          file not found on SFTP, schema mismatch

F03 Multi-object import (parent + child records)
    S02 login -> S03 dashboard -> S05 source -> S06 config ->
    S07 pick parent object -> S07 add child object(s) ->
    S08 map parent fields -> S08 map child fields + lookup resolution ->
    S10 preview -> S11 run (parent first, then children) -> S12 results
    happy path clicks: 10
    edge: parent insert fails → children orphaned, lookup resolution miss,
          circular relationships, mixed operation types

F04 Salesforce-to-Salesforce migration
    S02 login -> S03 dashboard -> S17 source org -> S19 object hierarchy ->
    S18 target org + field mapping -> S20 preview -> S20 test run ->
    S21 automation control (optional) -> S20 full run -> S12 results
    happy path clicks: 7
    edge: schema mismatch between orgs, missing fields in target,
          ID remapping failures, file/attachment transfer errors

F05 Sandbox seeding with reusable template
    S02 login -> S03 dashboard -> S16 templates -> select saved migration template ->
    S18 pick target sandbox -> S20 preview + run -> S12 results
    happy path clicks: 5
    edge: sandbox just refreshed (empty), template references deleted objects,
          SOQL filter returns 0 records

F06 Schedule a recurring import job
    S16 saved jobs -> select job -> S22 scheduling config ->
    set frequency + timezone -> enable schedule -> S03 dashboard (monitor)
    happy path clicks: 4
    edge: source file not updated, schedule overlaps with running job,
          Salesforce maintenance window, API limits exhausted

F07 Configure automated daily backup
    S02 login -> S23 backup dashboard -> S24 new backup policy ->
    select objects + retention + compression -> save & activate ->
    S23 monitor backup runs
    happy path clicks: 5
    edge: object has too many records, storage limit reached,
          ContentVersion files skipped, API governor limit

F08 Restore records from backup (rollback)
    S23 backup dashboard -> S25 snapshot history -> select snapshot ->
    S26 filter to target records -> compare before/after ->
    selective restore -> confirm -> S26 restore in progress -> done
    happy path clicks: 6
    edge: record was deleted AND recreated, field-level conflicts,
          lookup references changed, formula fields recomputed

F09 Rollback a completed import job
    S03 dashboard -> S12 job results -> S13 successful records ->
    click Rollback -> S15 confirmation modal -> execute -> S12 updated results
    happy path clicks: 4
    edge: records already modified by another process, related child records exist,
          cascade delete implications

F10 Build a multi-step flow (data pipeline)
    S02 login -> S32 flows builder -> add step 1 (import job) ->
    add step 2 (dependent import) -> configure error handling ->
    S22 schedule (optional) -> save & run flow -> monitor each step
    happy path clicks: 6
    edge: step 2 depends on step 1 output, mid-flow failure,
          retry vs skip logic, partial rollback of pipeline

F11 Connect and configure an external connector
    S03 dashboard -> S27 connector settings -> add new connector ->
    enter credentials (S3 keys / SFTP host / DB connection string) ->
    test connection -> save
    happy path clicks: 4
    edge: network/firewall blocking, wrong credentials, IP whitelist needed,
          SSL certificate issues

F12 Export data from Salesforce
    S03 dashboard -> S05 (or New Export) -> S07 pick object ->
    configure SOQL/fields -> run export -> download CSV or push to connector
    happy path clicks: 5
    edge: too many records for single export, timeout, field-level security

F13 Delete records via file upload
    S03 dashboard -> S05 source (CSV with IDs) -> S07 pick object + Delete operation ->
    S08 map ID field -> S10 preview -> S11 run -> S12 results (soft delete to recycle bin)
    happy path clicks: 6
    edge: record locked, record has children, insufficient permissions

F14 ISV/Partner: deploy locked template to customer org
    S31 partner admin -> create/select locked template ->
    assign to customer org(s) -> customer runs template in their org ->
    S12 results
    happy path clicks: 4
    edge: customer org schema differs, template version mismatch,
          customer lacks required permissions
```

---

## Components

| component                    | variants                                                                         | states                                                           | used on                                 |
| ---------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------- |
| Button                       | primary, secondary, ghost, danger, icon-only                                     | default, hover, focus, disabled, loading                         | all                                     |
| Org selector dropdown        | single-select, with status badge                                                 | default, open, loading orgs, error                               | S03, S04, S17, S18                      |
| File upload dropzone         | drag-and-drop, click-to-browse                                                   | idle, dragging over, file selected, uploading, upload error      | S06                                     |
| Object picker                | searchable dropdown, standard + custom objects                                   | default, searching, selected, multi-select                       | S07, S19, S24                           |
| Field mapping table          | two-column (source→target), with auto-match                                      | auto-mapped, manually adjusted, unmapped warning, formula inline | S08, S18                                |
| Formula editor               | inline bar, function autocomplete                                                | empty, formula entered, syntax error, preview result             | S09, S08                                |
| Filter / rule builder        | visual row-based rules, SQL WHERE editor                                         | no filters, filters active, syntax error                         | S09, S17                                |
| Data preview table           | paginated, sortable, with validation indicators                                  | loading, populated, empty, validation errors highlighted         | S10, S20, S26                           |
| Progress bar                 | determinate (% complete), with counters                                          | running, paused, completed, failed                               | S11                                     |
| Job results summary card     | success/fail counts, action buttons                                              | all success, partial failure, all failed                         | S12                                     |
| Error table                  | paginated, row #, field, error code, message                                     | errors present, empty                                            | S14                                     |
| Rollback confirmation modal  | modal dialog, record count, scope description                                    | pending, in progress, complete, failed                           | S15                                     |
| Schedule frequency picker    | radio/dropdown (15min, hourly, daily, weekly, custom)                            | no schedule, schedule set, schedule paused                       | S22                                     |
| Backup policy card           | object list, retention slider, compression toggle                                | new, active, paused, nearing storage limit                       | S24                                     |
| Snapshot timeline            | calendar/list view, per-object delta counts                                      | populated, single detail, empty                                  | S25                                     |
| Record comparison viewer     | side-by-side before/after field values                                           | loaded, diff highlighted, no changes                             | S26                                     |
| Connector config form        | type-specific credential fields, test button                                     | new, configured, test pass, test fail                            | S27                                     |
| Automation control checklist | toggle switches per Flow/Trigger/Validation Rule                                 | all active, some deactivated, restoring                          | S21                                     |
| Notification toggle list     | per-event-type toggles + email recipient input                                   | defaults, customized                                             | S30                                     |
| Flow step list / canvas      | sequential step cards, add/remove/reorder                                        | empty, multi-step, error on step                                 | S32                                     |
| Hierarchy tree               | drag-and-drop parent-child object tree                                           | single node, multi-level, with SOQL filters                      | S19                                     |
| Toast / Alert                | success, warning, error, info                                                    | visible, dismissing                                              | all                                     |
| Navigation sidebar           | collapsible, icon + label, sections (Import, Migration, Backup, Flows, Settings) | expanded, collapsed, active item highlighted                     | all authenticated screens               |
| Search bar                   | inline search with debounce                                                      | empty, typing, results, no results                               | S07, S16, S26                           |
| Usage meter / bar chart      | horizontal bar, daily trend line chart                                           | normal, warning (approaching limit), critical                    | S29                                     |
| User / team list             | table with role badges, action buttons                                           | single user, multi-user, pending invite                          | S28                                     |
| Tab bar                      | horizontal tabs within a page                                                    | active tab, inactive, disabled                                   | S12 (Results/Errors/Rollback), S16, S23 |

---

## Inferred data model

```
User  id, email, name, role (admin | user), org_id, created_at, last_login
      evidence: S02 login, S28 team management
      confidence: high

Organization  id, name, plan (free | premium | enterprise | partner), billing_email,
              max_records, max_api_calls, storage_quota_gb, created_at
      evidence: S03 dashboard, pricing page
      confidence: high

SalesforceOrg  id, org_id (→ Organization), sf_instance_url, sf_org_id, sf_org_type
               (production | sandbox | developer), access_token (encrypted),
               refresh_token (encrypted), connected_by (→ User), connected_at,
               status (active | disconnected | error), label
      evidence: S04 org connection manager, OAuth flow
      confidence: high

Connector  id, org_id (→ Organization), type (s3 | sftp | postgres | heroku_postgres |
           google_drive | google_sheets | sharepoint | snowflake | azure_sql),
           name, config_json (encrypted — host, port, bucket, credentials),
           created_by (→ User), created_at, last_tested_at, status (active | error)
      evidence: S27 connector settings, S06 source config
      confidence: high

Job  id, org_id (→ Organization), name, source_type (csv | excel | s3 | sftp | database |
     google_drive | google_sheets | sharepoint | snowflake | azure_sql | salesforce_org),
     source_config_json, target_sf_org_id (→ SalesforceOrg), operation (insert | update |
     upsert | delete | export), is_template (bool), is_locked (bool — partner),
     created_by (→ User), created_at, updated_at
      evidence: S05-S12, S16 saved jobs
      confidence: high

JobObject  id, job_id (→ Job), sf_object_api_name, parent_job_object_id (→ self, nullable),
           load_order (int), soql_filter, operation_override
      evidence: S07 multi-object, S19 hierarchy tree
      confidence: high

FieldMapping  id, job_object_id (→ JobObject), source_column, target_field_api_name,
              is_lookup (bool), lookup_object, lookup_match_field, formula (nullable),
              is_auto_matched (bool)
      evidence: S08 field mapping table
      confidence: high

TransformRule  id, job_object_id (→ JobObject), rule_type (formula | filter | dedup),
               expression, order (int)
      evidence: S09 transformations
      confidence: medium

JobRun  id, job_id (→ Job), sf_org_id (→ SalesforceOrg), status (queued | running |
        completed | failed | cancelled | rolled_back), started_at, completed_at,
        total_records, success_count, error_count, is_sample_run (bool),
        triggered_by (manual | schedule | flow), pre_snapshot_id (→ BackupSnapshot, nullable)
      evidence: S11 progress, S12 results
      confidence: high

JobRunRecord  id, job_run_id (→ JobRun), row_number, sf_record_id (nullable),
              status (success | error), error_code, error_message,
              original_values_json (for rollback)
      evidence: S13 successful records, S14 error records
      confidence: high

Schedule  id, job_id (→ Job), frequency (15min | hourly | daily | weekly | custom),
          cron_expression, timezone, start_date, end_date (nullable), is_active (bool),
          last_run_at, next_run_at
      evidence: S22 scheduling config
      confidence: high

Flow  id, org_id (→ Organization), name, description, created_by (→ User),
      created_at, updated_at, is_active (bool)
      evidence: S32 flows builder
      confidence: medium

FlowStep  id, flow_id (→ Flow), step_order (int), job_id (→ Job),
          on_error (stop | skip | retry), retry_count (int), depends_on_step_id (→ self, nullable)
      evidence: S32 flows builder
      confidence: medium

BackupPolicy  id, org_id (→ Organization), sf_org_id (→ SalesforceOrg), name,
              objects (json array of API names), include_files (bool),
              retention_days (int, up to 365), compression (gzip | none),
              is_active (bool), created_at
      evidence: S24 backup policy config
      confidence: high

BackupSnapshot  id, policy_id (→ BackupPolicy), snapshot_date, type (full | incremental),
                storage_path_s3, size_bytes, records_captured, inserts_delta,
                updates_delta, deletes_delta, status (completed | failed)
      evidence: S25 snapshot history
      confidence: high

BackupRecord  id, snapshot_id (→ BackupSnapshot), sf_object_api_name, sf_record_id,
              change_type (insert | update | delete), field_values_json,
              previous_values_json (for update/delete)
      evidence: S26 restore/rollback comparison
      confidence: medium

AutomationControl  id, job_run_id (→ JobRun), sf_metadata_type (flow | trigger | validation_rule),
                   sf_metadata_api_name, action (deactivate_before | reactivate_after),
                   original_state (active | inactive), status (toggled | restored | failed)
      evidence: S21 automation control panel
      confidence: medium

Notification  id, org_id (→ Organization), event_type (job_success | job_failure |
              schedule_missed | backup_complete | api_limit_warning),
              channel (email), recipients (json array), is_enabled (bool)
      evidence: S30 notification settings
      confidence: medium
```

**Relationships:**

- Organization 1-n User, 1-n SalesforceOrg, 1-n Connector, 1-n Job, 1-n Flow, 1-n BackupPolicy, 1-n Notification
- Job 1-n JobObject, 1-n JobRun, 0-1 Schedule
- JobObject 1-n FieldMapping, 1-n TransformRule, 0-1 JobObject (parent — self-referential hierarchy)
- JobRun 1-n JobRunRecord, 0-n AutomationControl
- Flow 1-n FlowStep, FlowStep n-1 Job
- BackupPolicy 1-n BackupSnapshot
- BackupSnapshot 1-n BackupRecord

---

## Feature matrix

See `features.csv`. Must: 28, should: 19, could: 10, skip: 4.

---

## Out of scope (cannot or should not be cloned)

- **Salesforce AppExchange marketplace listing** — requires Salesforce security review and ISV partnership, not a product feature to rebuild
- **Existing customer base and trust/reviews** — earned, not built
- **Salesforce's internal OAuth token infrastructure** — we integrate with it, we don't replicate it
- **Third-party cloud provider infrastructure** (AWS S3, Google Drive, Snowflake, Azure SQL) — we write connectors to them, we don't replicate the services themselves
- **Dataimporter's encrypted credential storage specifics** — we implement our own secure vault, not copy theirs

---

## Size

Screens 32, flows 14, entities 16. Hard parts: Salesforce Bulk/Metadata API integration, multi-object relationship resolution with ID remapping ("Magic ID"), real-time delta-tracking backup system, automation control (deactivate/reactivate Flows/Triggers via Metadata API), connector credential encryption and secure storage, robust error recovery and rollback at record level. Size: **L** (a quarter — this is a full-featured data platform with deep Salesforce API integration, multiple connector types, backup/restore, and scheduling infrastructure).
