-- 007_add_registration_children.sql
-- Tracks each registered child individually (name, age, allergies/dietary notes) instead
-- of just a headcount, matching how the community actually used the old registration
-- form and the D_Kinder table in the previous GemeindeEvents database.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

create table if not exists public.registration_children (
  id uuid primary key default gen_random_uuid(),
  registration_id uuid not null references public.registrations(id) on delete cascade,
  first_name text,
  last_name text,
  age integer,
  allergies text,
  created_at timestamptz not null default now()
);

alter table public.registration_children enable row level security;

-- A visitor can add children to a registration for a published event (mirrors registrations_public_insert).
drop policy if exists "registration_children_public_insert" on public.registration_children;
create policy "registration_children_public_insert" on public.registration_children for insert
  with check (exists (
    select 1 from public.registrations r
    join public.events e on e.id = r.event_id
    where r.id = registration_id and e.status = 'published'
  ));

drop policy if exists "registration_children_staff_select" on public.registration_children;
create policy "registration_children_staff_select" on public.registration_children for select
  using (auth.role() = 'authenticated');
drop policy if exists "registration_children_staff_update" on public.registration_children;
create policy "registration_children_staff_update" on public.registration_children for update
  using (auth.role() = 'authenticated');
drop policy if exists "registration_children_staff_delete" on public.registration_children;
create policy "registration_children_staff_delete" on public.registration_children for delete
  using (auth.role() = 'authenticated');
