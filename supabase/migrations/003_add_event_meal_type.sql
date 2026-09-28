-- 003_add_event_meal_type.sql
-- Replaces the earlier simple "has_meal" idea with a proper meal type,
-- so an event can say what kind of food is offered (or none).
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.events add column if not exists meal_type text not null default 'none';

alter table public.events drop constraint if exists events_meal_type_check;
alter table public.events add constraint events_meal_type_check
  check (meal_type in ('none', 'meal', 'buffet', 'snack'));

-- If an older has_meal column exists from a previous draft migration, drop it
-- (meal_type replaces it and carries more detail).
alter table public.events drop column if exists has_meal;
