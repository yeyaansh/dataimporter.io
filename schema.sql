-- =============================================================================
-- DataImporter Clone — Full Database Schema
-- PostgreSQL 15+ on Supabase (or Neon)
-- All times are timestamptz (UTC). Money is integer cents + currency.
-- IDs are uuid via gen_random_uuid(). RLS enforced at the data-layer level.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- trigram indexes for search

-- ---------------------------------------------------------------------------
-- 1. organizations
-- ---------------------------------------------------------------------------
create table organizations (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  plan            text not null default 'free'
                    check (plan in ('free','premium','enterprise','partner')),
  billing_email   text,
  max_records     bigint not null default 20000,
  max_api_calls   bigint not null default 100000,
  storage_quota_bytes bigint not null default 1073741824, -- 1 GB
  storage_used_bytes  bigint not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. users
-- ---------------------------------------------------------------------------
create table users (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  email           text not null,
  name            text not null default '',
  role            text not null default 'user'
                    check (role in ('admin','user')),
  sf_user_id      text,                       -- Salesforce User ID from OAuth
  avatar_url      text,
  last_login_at   timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (email)
);
create index idx_users_org on users (org_id);
create index idx_users_email on users (email);

-- ---------------------------------------------------------------------------
-- 3. salesforce_orgs — connected Salesforce environments
-- ---------------------------------------------------------------------------
create table salesforce_orgs (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  sf_instance_url text not null,                -- e.g. https://na1.salesforce.com
  sf_org_id       text not null,                -- 15/18-char Salesforce org ID
  sf_org_type     text not null default 'production'
                    check (sf_org_type in ('production','sandbox','developer','scratch')),
  label           text not null default '',
  access_token    text not null,                -- encrypted at app layer
  refresh_token   text not null,                -- encrypted at app layer
  token_expires_at timestamptz,
  connected_by    uuid not null references users(id) on delete set null,
  status          text not null default 'active'
                    check (status in ('active','disconnected','error','refreshing')),
  api_calls_today bigint not null default 0,
  api_calls_limit bigint not null default 0,    -- fetched from org limits
  connected_at    timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (org_id, sf_org_id)
);
create index idx_sf_orgs_org on salesforce_orgs (org_id);
create index idx_sf_orgs_status on salesforce_orgs (org_id, status);

-- ---------------------------------------------------------------------------
-- 4. connectors — external data-source connections
-- ---------------------------------------------------------------------------
create table connectors (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  type            text not null
                    check (type in ('s3','sftp','postgres','heroku_postgres',
                                    'google_drive','google_sheets','sharepoint',
                                    'snowflake','azure_sql','mysql')),
  name            text not null,
  config_encrypted bytea not null,              -- AES-256-GCM envelope
  status          text not null default 'active'
                    check (status in ('active','error','testing')),
  created_by      uuid not null references users(id) on delete set null,
  last_tested_at  timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_connectors_org on connectors (org_id);

-- ---------------------------------------------------------------------------
-- 5. jobs — an import, export, delete, or migration configuration
-- ---------------------------------------------------------------------------
create table jobs (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  name            text not null,
  job_type        text not null default 'import'
                    check (job_type in ('import','export','migration')),
  source_type     text not null
                    check (source_type in ('csv','excel','s3','sftp','postgres',
                                           'heroku_postgres','google_drive',
                                           'google_sheets','sharepoint',
                                           'snowflake','azure_sql','mysql',
                                           'salesforce_org')),
  source_connector_id uuid references connectors(id) on delete set null,
  source_sf_org_id    uuid references salesforce_orgs(id) on delete set null,
  source_config   jsonb not null default '{}',  -- file path, bucket, SQL, SOQL
  target_sf_org_id uuid not null references salesforce_orgs(id) on delete cascade,
  operation       text not null default 'insert'
                    check (operation in ('insert','update','upsert','delete','export')),
  is_template     boolean not null default false,
  is_locked       boolean not null default false,  -- partner/ISV locked
  enable_pre_snapshot boolean not null default false,
  created_by      uuid not null references users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_jobs_org on jobs (org_id);
create index idx_jobs_org_type on jobs (org_id, job_type);
create index idx_jobs_template on jobs (org_id) where is_template = true;

-- ---------------------------------------------------------------------------
-- 6. job_objects — objects within a multi-object job, with hierarchy
-- ---------------------------------------------------------------------------
create table job_objects (
  id              uuid primary key default gen_random_uuid(),
  job_id          uuid not null references jobs(id) on delete cascade,
  sf_object_api_name text not null,             -- e.g. Account, Contact, Custom__c
  parent_job_object_id uuid references job_objects(id) on delete set null,
  load_order      int not null default 0,       -- 0 = root, 1 = first child, etc.
  soql_filter     text,                         -- WHERE clause for migration/export
  operation_override text                       -- override job-level operation per object
                    check (operation_override is null or
                           operation_override in ('insert','update','upsert','delete','export')),
  include_files   boolean not null default false,
  created_at      timestamptz not null default now()
);
create index idx_job_objects_job on job_objects (job_id, load_order);

-- ---------------------------------------------------------------------------
-- 7. field_mappings — column-to-field mapping per object
-- ---------------------------------------------------------------------------
create table field_mappings (
  id              uuid primary key default gen_random_uuid(),
  job_object_id   uuid not null references job_objects(id) on delete cascade,
  source_column   text not null,
  target_field    text not null,                -- Salesforce field API name
  is_lookup       boolean not null default false,
  lookup_object   text,                         -- related object API name
  lookup_match_field text,                      -- field to match on (e.g. Name, ExternalId__c)
  formula         text,                         -- e.g. IF(ISNULL($source), 'N/A', $source)
  is_auto_matched boolean not null default false,
  mapping_order   int not null default 0,
  created_at      timestamptz not null default now()
);
create index idx_field_mappings_obj on field_mappings (job_object_id, mapping_order);

-- ---------------------------------------------------------------------------
-- 8. transform_rules — data transformations and filters per object
-- ---------------------------------------------------------------------------
create table transform_rules (
  id              uuid primary key default gen_random_uuid(),
  job_object_id   uuid not null references job_objects(id) on delete cascade,
  rule_type       text not null
                    check (rule_type in ('formula','filter','dedup','default_value')),
  expression      text not null,                -- the formula or filter expression
  target_field    text,                         -- field this rule applies to (null for row filters)
  rule_order      int not null default 0,
  created_at      timestamptz not null default now()
);
create index idx_transform_rules_obj on transform_rules (job_object_id, rule_order);

-- ---------------------------------------------------------------------------
-- 9. job_runs — each execution of a job
-- ---------------------------------------------------------------------------
create table job_runs (
  id              uuid primary key default gen_random_uuid(),
  job_id          uuid not null references jobs(id) on delete cascade,
  sf_org_id       uuid not null references salesforce_orgs(id) on delete cascade,
  status          text not null default 'queued'
                    check (status in ('queued','running','completed','failed',
                                      'cancelled','rolled_back')),
  total_records   bigint not null default 0,
  success_count   bigint not null default 0,
  error_count     bigint not null default 0,
  is_sample_run   boolean not null default false,
  sample_size     int,                          -- null = full run
  triggered_by    text not null default 'manual'
                    check (triggered_by in ('manual','schedule','flow','retry')),
  pre_snapshot_id uuid,                         -- FK added after backup_snapshots exists
  progress_pct    smallint not null default 0
                    check (progress_pct between 0 and 100),
  current_object  text,                         -- currently processing object API name
  worker_id       text,                         -- which worker instance is processing
  sf_bulk_job_ids jsonb not null default '[]',  -- Bulk API 2.0 job IDs for tracking
  error_log       text,                         -- summary error message
  started_at      timestamptz,
  completed_at    timestamptz,
  created_at      timestamptz not null default now()
);
create index idx_job_runs_job on job_runs (job_id, created_at desc);
create index idx_job_runs_status on job_runs (status) where status in ('queued','running');
create index idx_job_runs_worker on job_runs (worker_id) where status = 'running';

-- ---------------------------------------------------------------------------
-- 10. job_run_records — per-record outcomes (success/error) for a run
--     For large jobs, these go to object storage (S3/R2) as gzipped CSV.
--     This table stores only records that need attention (errors, rollback).
-- ---------------------------------------------------------------------------
create table job_run_records (
  id              uuid primary key default gen_random_uuid(),
  job_run_id      uuid not null references job_runs(id) on delete cascade,
  job_object_id   uuid not null references job_objects(id) on delete cascade,
  row_number      bigint not null,
  sf_record_id    text,                         -- 15/18-char Salesforce ID
  status          text not null
                    check (status in ('success','error')),
  error_code      text,                         -- e.g. REQUIRED_FIELD_MISSING
  error_message   text,
  original_values jsonb,                        -- pre-update values for rollback
  created_at      timestamptz not null default now()
);
create index idx_jrr_run on job_run_records (job_run_id, status);
create index idx_jrr_sf_id on job_run_records (sf_record_id) where sf_record_id is not null;

-- Partition strategy note: for high-volume orgs, partition job_run_records
-- by job_run_id or created_at range. Evaluate when >10M rows.

-- ---------------------------------------------------------------------------
-- 11. id_remap_cache — Magic ID: maps source SF IDs to target SF IDs
--     during multi-object imports and org-to-org migrations
-- ---------------------------------------------------------------------------
create table id_remap_cache (
  id              uuid primary key default gen_random_uuid(),
  job_run_id      uuid not null references job_runs(id) on delete cascade,
  sf_object_api_name text not null,
  source_record_id text not null,               -- ID in source org / file
  target_record_id text not null,               -- newly created ID in target org
  created_at      timestamptz not null default now()
);
create unique index idx_id_remap_lookup
  on id_remap_cache (job_run_id, sf_object_api_name, source_record_id);

-- ---------------------------------------------------------------------------
-- 12. schedules — recurring job execution
-- ---------------------------------------------------------------------------
create table schedules (
  id              uuid primary key default gen_random_uuid(),
  job_id          uuid not null references jobs(id) on delete cascade,
  frequency       text not null
                    check (frequency in ('15min','hourly','daily','weekly','custom')),
  cron_expression text not null,                -- e.g. '0 */6 * * *'
  timezone        text not null default 'UTC',  -- IANA timezone
  start_date      timestamptz not null default now(),
  end_date        timestamptz,
  is_active       boolean not null default true,
  last_run_at     timestamptz,
  next_run_at     timestamptz,
  consecutive_failures int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (job_id)
);
create index idx_schedules_next on schedules (next_run_at)
  where is_active = true;

-- ---------------------------------------------------------------------------
-- 13. flows — multi-step data pipeline
-- ---------------------------------------------------------------------------
create table flows (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  name            text not null,
  description     text not null default '',
  is_active       boolean not null default true,
  created_by      uuid not null references users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_flows_org on flows (org_id);

-- ---------------------------------------------------------------------------
-- 14. flow_steps — each step in a flow
-- ---------------------------------------------------------------------------
create table flow_steps (
  id              uuid primary key default gen_random_uuid(),
  flow_id         uuid not null references flows(id) on delete cascade,
  job_id          uuid not null references jobs(id) on delete cascade,
  step_order      int not null,
  on_error        text not null default 'stop'
                    check (on_error in ('stop','skip','retry')),
  max_retries     int not null default 0,
  depends_on_step_id uuid references flow_steps(id) on delete set null,
  created_at      timestamptz not null default now()
);
create index idx_flow_steps_flow on flow_steps (flow_id, step_order);

-- ---------------------------------------------------------------------------
-- 15. flow_runs — execution of an entire flow
-- ---------------------------------------------------------------------------
create table flow_runs (
  id              uuid primary key default gen_random_uuid(),
  flow_id         uuid not null references flows(id) on delete cascade,
  status          text not null default 'queued'
                    check (status in ('queued','running','completed','failed','cancelled')),
  current_step_id uuid references flow_steps(id) on delete set null,
  triggered_by    text not null default 'manual'
                    check (triggered_by in ('manual','schedule')),
  started_at      timestamptz,
  completed_at    timestamptz,
  created_at      timestamptz not null default now()
);
create index idx_flow_runs_flow on flow_runs (flow_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 16. flow_step_runs — per-step execution within a flow run
-- ---------------------------------------------------------------------------
create table flow_step_runs (
  id              uuid primary key default gen_random_uuid(),
  flow_run_id     uuid not null references flow_runs(id) on delete cascade,
  flow_step_id    uuid not null references flow_steps(id) on delete cascade,
  job_run_id      uuid references job_runs(id) on delete set null,
  status          text not null default 'pending'
                    check (status in ('pending','running','completed','failed','skipped')),
  attempt         int not null default 1,
  started_at      timestamptz,
  completed_at    timestamptz,
  created_at      timestamptz not null default now()
);
create index idx_fsr_flow_run on flow_step_runs (flow_run_id, flow_step_id);

-- ---------------------------------------------------------------------------
-- 17. backup_policies — automated backup configuration
-- ---------------------------------------------------------------------------
create table backup_policies (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  sf_org_id       uuid not null references salesforce_orgs(id) on delete cascade,
  name            text not null,
  objects         jsonb not null default '[]',   -- ["Account","Contact","Opportunity"]
  include_files   boolean not null default false,
  retention_days  int not null default 30
                    check (retention_days between 1 and 365),
  compression     text not null default 'gzip'
                    check (compression in ('gzip','none')),
  is_active       boolean not null default true,
  last_run_at     timestamptz,
  next_run_at     timestamptz,
  consecutive_failures int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_backup_policies_org on backup_policies (org_id, sf_org_id);
create index idx_backup_policies_next on backup_policies (next_run_at)
  where is_active = true;

-- ---------------------------------------------------------------------------
-- 18. backup_snapshots — each daily backup run
-- ---------------------------------------------------------------------------
create table backup_snapshots (
  id              uuid primary key default gen_random_uuid(),
  policy_id       uuid not null references backup_policies(id) on delete cascade,
  snapshot_date   date not null,
  snapshot_type   text not null default 'incremental'
                    check (snapshot_type in ('full','incremental')),
  storage_path    text not null,                -- R2/S3 prefix: backups/{org}/{date}/
  size_bytes      bigint not null default 0,
  records_total   bigint not null default 0,
  inserts_delta   bigint not null default 0,
  updates_delta   bigint not null default 0,
  deletes_delta   bigint not null default 0,
  status          text not null default 'running'
                    check (status in ('running','completed','failed')),
  started_at      timestamptz not null default now(),
  completed_at    timestamptz,
  created_at      timestamptz not null default now()
);
create index idx_snapshots_policy on backup_snapshots (policy_id, snapshot_date desc);
create unique index idx_snapshots_policy_date
  on backup_snapshots (policy_id, snapshot_date);

-- Now add the FK from job_runs
alter table job_runs
  add constraint fk_job_runs_snapshot
    foreign key (pre_snapshot_id) references backup_snapshots(id)
    on delete set null;

-- ---------------------------------------------------------------------------
-- 19. backup_records — per-record change tracking in a snapshot
--     For large objects, this is stored as gzipped JSONL in object storage;
--     the table holds metadata and pointers.
-- ---------------------------------------------------------------------------
create table backup_records (
  id              uuid primary key default gen_random_uuid(),
  snapshot_id     uuid not null references backup_snapshots(id) on delete cascade,
  sf_object_api_name text not null,
  sf_record_id    text not null,
  change_type     text not null
                    check (change_type in ('insert','update','delete','unchanged')),
  field_values    jsonb,                        -- current field values
  previous_values jsonb,                        -- prior values (for update/delete)
  created_at      timestamptz not null default now()
);
create index idx_backup_records_snapshot on backup_records (snapshot_id, sf_object_api_name);
create index idx_backup_records_sf_id on backup_records (snapshot_id, sf_record_id);

-- Partition note: partition backup_records by snapshot_id when >50M rows.

-- ---------------------------------------------------------------------------
-- 20. automation_controls — SF automation toggle log per job run
-- ---------------------------------------------------------------------------
create table automation_controls (
  id              uuid primary key default gen_random_uuid(),
  job_run_id      uuid not null references job_runs(id) on delete cascade,
  sf_metadata_type text not null
                    check (sf_metadata_type in ('flow','trigger','validation_rule',
                                                'process_builder','workflow_rule')),
  sf_metadata_api_name text not null,
  original_state  text not null
                    check (original_state in ('active','inactive')),
  action          text not null
                    check (action in ('deactivate_before','reactivate_after')),
  status          text not null default 'pending'
                    check (status in ('pending','toggled','restored','failed')),
  toggled_at      timestamptz,
  restored_at     timestamptz,
  error_message   text,
  created_at      timestamptz not null default now()
);
create index idx_auto_controls_run on automation_controls (job_run_id);

-- ---------------------------------------------------------------------------
-- 21. notifications — alert preferences per org
-- ---------------------------------------------------------------------------
create table notifications (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  event_type      text not null
                    check (event_type in ('job_success','job_failure','schedule_missed',
                                          'backup_complete','backup_failure',
                                          'api_limit_warning','flow_failure')),
  channel         text not null default 'email'
                    check (channel in ('email','webhook')),
  recipients      jsonb not null default '[]',  -- ["admin@co.com","ops@co.com"]
  is_enabled      boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (org_id, event_type, channel)
);
create index idx_notifications_org on notifications (org_id);

-- ---------------------------------------------------------------------------
-- 22. uploaded_files — temporarily stored CSV/Excel uploads
-- ---------------------------------------------------------------------------
create table uploaded_files (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  file_name       text not null,
  mime_type       text not null,
  size_bytes      bigint not null,
  storage_path    text not null,                -- R2/S3 path
  parsed_headers  jsonb,                        -- column names extracted from first row
  row_count       bigint,
  uploaded_by     uuid not null references users(id) on delete set null,
  expires_at      timestamptz not null default (now() + interval '24 hours'),
  created_at      timestamptz not null default now()
);
create index idx_uploaded_files_org on uploaded_files (org_id);
create index idx_uploaded_files_expiry on uploaded_files (expires_at)
  where expires_at is not null;

-- ---------------------------------------------------------------------------
-- 23. api_usage_log — Salesforce API call tracking per org per day
-- ---------------------------------------------------------------------------
create table api_usage_log (
  id              uuid primary key default gen_random_uuid(),
  sf_org_id       uuid not null references salesforce_orgs(id) on delete cascade,
  log_date        date not null default current_date,
  calls_used      bigint not null default 0,
  calls_limit     bigint not null default 0,
  bulk_batches    bigint not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (sf_org_id, log_date)
);
create index idx_api_usage_sf_org on api_usage_log (sf_org_id, log_date desc);

-- ---------------------------------------------------------------------------
-- 24. audit_log — who did what (immutable)
-- ---------------------------------------------------------------------------
create table audit_log (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  user_id         uuid references users(id) on delete set null,
  action          text not null,                -- e.g. 'job.run','backup.restore','org.connect'
  resource_type   text not null,                -- 'job','backup_policy','salesforce_org'
  resource_id     uuid,
  metadata        jsonb not null default '{}',
  ip_address      inet,
  created_at      timestamptz not null default now()
);
create index idx_audit_org on audit_log (org_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 25. flow_schedules — optional schedule attached to a flow
-- ---------------------------------------------------------------------------
create table flow_schedules (
  id              uuid primary key default gen_random_uuid(),
  flow_id         uuid not null references flows(id) on delete cascade,
  cron_expression text not null,
  timezone        text not null default 'UTC',
  is_active       boolean not null default true,
  next_run_at     timestamptz,
  last_run_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (flow_id)
);
create index idx_flow_schedules_next on flow_schedules (next_run_at)
  where is_active = true;
