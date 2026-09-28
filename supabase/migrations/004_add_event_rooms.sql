-- 004_add_event_rooms.sql
-- Stores which rooms/spaces are reserved for an event (internal planning, not shown publicly).
-- Shape: jsonb array, e.g. [{"name": "Gemeindesaal", "image_url": "https://..."}, ...]
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.events add column if not exists rooms jsonb not null default '[]'::jsonb;
