-- 006_add_registration_details.sql
-- Brings the public registration form up to what was actually used in past events
-- (see the old GemeindeEvents SQL Server database and the real Google Forms):
-- community membership status, a per-event participation fee for non-members,
-- and the GDPR data-processing consent that every registration legally needs.
-- privacy_consent is enforced as required in the register.html form itself, not via a
-- DB check constraint, so this migration stays safe to run on top of existing test data.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.events add column if not exists non_member_fee numeric(10,2);

alter table public.registrations add column if not exists member_status text not null default 'unknown';
alter table public.registrations drop constraint if exists registrations_member_status_check;
alter table public.registrations add constraint registrations_member_status_check
  check (member_status in ('yes', 'no', 'unknown'));

alter table public.registrations add column if not exists privacy_consent boolean not null default false;
alter table public.registrations add column if not exists fee_consent boolean;
alter table public.registrations add column if not exists under6_supervision_ack boolean;
