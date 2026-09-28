-- 012_add_registration_deadline.sql
-- Anmeldeschluss: an optional cutoff after which the public registration form
-- stops accepting new sign-ups for that event. Mirrors D_Veranstaltung.Anmeldeschluss
-- from the old GemeindeEvents database (see architecture doc, Backlog).
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.events add column if not exists registration_deadline timestamptz;
