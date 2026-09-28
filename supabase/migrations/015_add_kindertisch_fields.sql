-- 015_add_kindertisch_fields.sql
-- Kindertisch (kids' table) support, requested 28.09.2026:
--  - events.has_kindertisch: per-event flag. Only events where this is true show the
--    "sitzt am Kindertisch / bei den Eltern" question in the registration form, since
--    not every event has a separate kids' table.
--  - registration_children.at_kindertisch: parent's choice per child (true = sits at
--    the Kindertisch, false/null = sits with parents). Not restricted by age -- parents
--    decide.
--  - registration_children.needs_high_chair: optional per-child request for a high
--    chair / booster seat, for very young children. Also parent-selected, no fixed
--    age cutoff enforced in the schema.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.events add column if not exists has_kindertisch boolean not null default false;
alter table public.registration_children add column if not exists at_kindertisch boolean;
alter table public.registration_children add column if not exists needs_high_chair boolean;
