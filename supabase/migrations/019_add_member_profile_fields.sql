-- 019_add_member_profile_fields.sql
-- Optional extra profile fields for the staff-maintained "Mitglieder"
-- registry (public.verified_members), requested 2026-09-28: besides name,
-- email and phone, Iryna wants to optionally record a full date of birth
-- and a postal address for community members. Both are nullable — nothing
-- required beyond what's already there.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.verified_members add column if not exists birth_date date;
alter table public.verified_members add column if not exists address text;
