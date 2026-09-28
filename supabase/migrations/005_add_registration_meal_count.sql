-- 005_add_registration_meal_count.sql
-- Tracks how many people a registration ordered a meal for (can differ from guests_count
-- if not everyone attending eats). Only meaningful when the event's meal_type is not 'none'.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.registrations add column if not exists meal_count integer;
