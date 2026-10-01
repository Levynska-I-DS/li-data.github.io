-- 024_add_kindertisch_age_limits.sql
-- Requested 01.10.2026: optional age limits for the Kindertisch, set per event.
-- Empty (null) = any age. Example: min 6, max 18 -> only children 6–18 can choose
-- "Am Kindertisch"; younger/older children sit "Bei den Eltern".
--
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.
-- IMPORTANT: run this BEFORE pushing the matching code, otherwise the
-- registration page cannot load the event (unknown columns).

alter table public.events add column if not exists kindertisch_min_age integer;
alter table public.events add column if not exists kindertisch_max_age integer;
