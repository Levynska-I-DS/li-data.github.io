-- 013_add_bi_reporting_role.sql
-- Read-only Postgres role for connecting Power BI / Tableau DIRECTLY to the
-- database (not through the anon/PostgREST key used by the website). See the
-- architecture doc for the full connection guide.
--
-- IMPORTANT before running this:
--   1. Replace REPLACE_ME_STRONG_PASSWORD_HERE below with your own strong password.
--   2. This repo is public — do not commit the real password. Either edit the
--      line back to a placeholder after running it once, or rotate the password
--      afterwards with: alter role bi_reporting password 'a-different-one';
--      (running that single line in the SQL editor does not need to be saved
--      to this file — this migration only needs to create the role once).
--   3. Store the real password only in Power BI's / Tableau's saved connection.
--
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole
-- file (after step 1 above) -> Run.

do $$
begin
  if not exists (select from pg_roles where rolname = 'bi_reporting') then
    create role bi_reporting login password 'REPLACE_ME_STRONG_PASSWORD_HERE';
  end if;
end
$$;

-- BYPASSRLS is intentional and safe here: this role has no membership in
-- "authenticated" and gets access to nothing except the explicit SELECT
-- grants below. Without BYPASSRLS, the existing RLS policies (which check
-- auth.role() = 'authenticated', a Supabase Auth/PostgREST concept that a
-- direct Postgres connection never has) would make every query return zero
-- rows even with SELECT granted.
-- Note: nosuperuser/noreplication removed below on purpose -- Supabase's SQL Editor
-- role isn't itself a superuser, so it isn't allowed to even state those two
-- attributes on another role (Postgres requires the caller to already hold an
-- attribute to touch it on someone else, even to explicitly say "off"). A plain
-- CREATE ROLE already defaults to nosuperuser/noreplication, so nothing is lost.
alter role bi_reporting bypassrls noinherit nocreatedb nocreaterole connection limit 5;
alter role bi_reporting set statement_timeout = '30s';

grant usage on schema public to bi_reporting;

-- Reporting-relevant tables only. Deliberately NOT granted: profiles,
-- verified_members (personal verification notes), event_invitations
-- (contains invite codes) — none of these are needed for registration
-- counts/demographics reporting.
grant select on
  public.events,
  public.registrations,
  public.registration_children,
  public.registration_order_items,
  public.sponsorships
to bi_reporting;

-- Any column added to these tables later stays visible without a new grant.
alter default privileges in schema public grant select on tables to bi_reporting;

-- Convenience: one flattened, already-joined table for a quick Power BI/Tableau
-- model, so Iryna doesn't have to rebuild the events<->registrations join every
-- time. The normalized tables above remain available for anything this view
-- doesn't cover (e.g. per-child rows, individual pre-order line items).
create or replace view public.registration_report as
select
  r.id as registration_id,
  e.slug as event_slug,
  e.title as event_title,
  e.starts_at as event_starts_at,
  e.location as event_location,
  r.full_name,
  r.email,
  r.phone,
  r.member_status,
  r.guests_count,
  r.meal_count,
  r.fee_consent,
  r.status as registration_status,
  r.created_at as registered_at,
  (select count(*) from public.registration_children c where c.registration_id = r.id) as children_count
from public.registrations r
join public.events e on e.id = r.event_id;

grant select on public.registration_report to bi_reporting;
