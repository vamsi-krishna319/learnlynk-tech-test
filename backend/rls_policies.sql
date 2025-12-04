-- Enable RLS on leads
alter table leads enable row level security;

-- (optional safety) Ensure no public access
revoke all on leads from public;

----------------------------------------------------------------
-- RLS Policy: SELECT
----------------------------------------------------------------
-- Rules:
-- Admins → can see all leads for their tenant
-- Counselors → can see:
--   (a) leads they own OR
--   (b) leads assigned to any team they belong to

create policy "allow_select_based_on_role_and_ownership" on leads
for select
using (
  tenant_id = auth.jwt() ->> 'tenant_id'
  AND (
    -- Admins → full visibility on tenant
    (auth.jwt() ->> 'role') = 'admin'
    OR
    -- Counselors → can see leads they own
    owner_id = (auth.jwt() ->> 'user_id')::uuid
    OR
    -- Counselors → can see leads assigned to their teams
    leads.id IN (
      select l.id
      from leads l
      join applications a on a.lead_id = l.id
      join user_teams ut on ut.user_id = (auth.jwt() ->> 'user_id')::uuid
      join teams t on t.id = ut.team_id and t.tenant_id = l.tenant_id
    )
  )
);
----------------------------------------------------------------


----------------------------------------------------------------
-- RLS Policy: INSERT
----------------------------------------------------------------
-- Admins & counselors may insert leads *only* inside their tenant
----------------------------------------------------------------

create policy "allow_insert_for_tenant_users" on leads
for insert
with check (
  tenant_id = auth.jwt() ->> 'tenant_id'
  AND (auth.jwt() ->> 'role') in ('admin', 'counselor')
);
----------------------------------------------------------------

