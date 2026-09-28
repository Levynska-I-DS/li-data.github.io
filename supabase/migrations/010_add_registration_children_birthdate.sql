-- 010_add_registration_children_birthdate.sql
-- Replaces the plain "age at registration" number with the child's actual date of
-- birth. A birth date never goes stale (unlike a typed-in age) and is what lets a
-- returning family be recognised again later without retyping the child's details.
-- The existing `age` column stays and keeps being filled in automatically (computed
-- from birth_date relative to the event date), so nothing else has to change.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.registration_children add column if not exists birth_date date;
