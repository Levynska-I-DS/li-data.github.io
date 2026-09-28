-- 002_add_event_image.sql
-- Adds an image field to events, plus a public storage bucket for event banners/flyers.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.events add column if not exists image_url text;

insert into storage.buckets (id, name, public)
values ('event-images', 'event-images', true)
on conflict (id) do nothing;

-- Anyone can view images in this public bucket.
create policy "event_images_public_read" on storage.objects for select
  using (bucket_id = 'event-images');

-- Only authenticated staff can upload, replace or delete event images.
create policy "event_images_staff_insert" on storage.objects for insert
  with check (bucket_id = 'event-images' and auth.role() = 'authenticated');

create policy "event_images_staff_update" on storage.objects for update
  using (bucket_id = 'event-images' and auth.role() = 'authenticated');

create policy "event_images_staff_delete" on storage.objects for delete
  using (bucket_id = 'event-images' and auth.role() = 'authenticated');
