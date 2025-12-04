-- Enable pgcrypto for gen_random_uuid() if not already enabled
create extension if not exists "pgcrypto";

----------------------------------------------------------------
-- Table: leads
----------------------------------------------------------------
create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  owner_id uuid,                         -- counselor/user who owns the lead
  stage text default 'new',              -- e.g., new, contacted, qualified, lost
  name text,
  email text,
  phone text,
  data jsonb default '{}'::jsonb,        -- flexible metadata
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes for typical queries
create index if not exists idx_leads_tenant_id on leads (tenant_id);
create index if not exists idx_leads_owner_id on leads (owner_id);
create index if not exists idx_leads_stage on leads (stage);

----------------------------------------------------------------
-- Table: applications
----------------------------------------------------------------
create table if not exists applications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  lead_id uuid not null references leads(id) on delete cascade,
  status text default 'active',          -- e.g., active, withdrawn, accepted
  product text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes
create index if not exists idx_applications_tenant_id on applications (tenant_id);
create index if not exists idx_applications_lead_id on applications (lead_id);

----------------------------------------------------------------
-- Table: tasks
----------------------------------------------------------------
create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  application_id uuid not null references applications(id) on delete cascade,
  type text not null,                     -- call | email | review
  status text not null default 'pending', -- pending | completed | canceled
  assignee_id uuid,                       -- user assigned
  description text,
  due_at timestamptz not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  -- Constraints
  constraint tasks_type_check check (type in ('call','email','review')),
  constraint tasks_status_check check (status in ('pending','completed','canceled')),
  constraint tasks_due_check check (due_at >= created_at)
);

-- Indexes for queries
create index if not exists idx_tasks_tenant_id on tasks (tenant_id);
create index if not exists idx_tasks_due_at on tasks (due_at);
create index if not exists idx_tasks_status on tasks (status);

----------------------------------------------------------------
-- Triggers (optional): auto-set updated_at on update
----------------------------------------------------------------
-- Function to update updated_at timestamp
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Attach trigger to tables
drop trigger if exists trg_leads_set_updated_at on leads;
create trigger trg_leads_set_updated_at
  before update on leads for each row execute procedure set_updated_at();

drop trigger if exists trg_applications_set_updated_at on applications;
create trigger trg_applications_set_updated_at
  before update on applications for each row execute procedure set_updated_at();

drop trigger if exists trg_tasks_set_updated_at on tasks;
create trigger trg_tasks_set_updated_at
  before update on tasks for each row execute procedure set_updated_at();
