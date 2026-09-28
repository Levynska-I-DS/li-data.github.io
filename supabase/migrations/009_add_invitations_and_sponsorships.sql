-- 009_add_invitations_and_sponsorships.sql
-- Adds two features from the original project brief that hadn't been built yet:
-- 1) Optional per-person invitation codes, so an event can be gated to only the
--    people Iryna invited (instead of the open ?event=slug link everyone can use today).
-- 2) A standalone sponsorship flow (Salat-Dekoration, Blumen, Zusätzliche Getränke,
--    Kinder-Cocktailbar, etc.) as its own page, separate from attendee registration.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

-- --- 1. Invitation codes -----------------------------------------------------

alter table public.events add column if not exists requires_code boolean not null default false;

create table if not exists public.event_invitations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  code text not null,
  guest_name text,
  registration_id uuid references public.registrations(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists event_invitations_event_code_idx
  on public.event_invitations (event_id, upper(code));

alter table public.event_invitations enable row level security;

-- Only staff can browse/manage the raw list of codes directly (never exposed to the
-- public as a whole table -- that would defeat the point of a per-person code).
drop policy if exists "event_invitations_staff_all" on public.event_invitations;
create policy "event_invitations_staff_all" on public.event_invitations
  for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- Public access to a single code happens only through this function, which returns
-- just the one matching invitation (if any) -- never the full list.
create or replace function public.validate_invitation(p_slug text, p_code text)
returns table (event_id uuid, invitation_id uuid, guest_name text)
language sql
security definer
set search_path = public
as $$
  select e.id, i.id, i.guest_name
  from public.events e
  join public.event_invitations i on i.event_id = e.id
  where e.slug = p_slug
    and e.status = 'published'
    and upper(i.code) = upper(p_code)
  limit 1;
$$;

grant execute on function public.validate_invitation(text, text) to anon, authenticated;

-- Marks an invitation as used once its holder actually registers. Only ever sets the
-- link the first time (registration_id is null), so a code can't be reassigned later.
create or replace function public.redeem_invitation(p_invitation_id uuid, p_registration_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.event_invitations
  set registration_id = p_registration_id
  where id = p_invitation_id and registration_id is null;
$$;

grant execute on function public.redeem_invitation(uuid, uuid) to anon, authenticated;

-- --- 2. Sponsorships ---------------------------------------------------------

-- Per-event list of sponsorship categories on offer (e.g. Salat-Dekoration, Blumen,
-- Zusätzliche Getränke, Kinder-Cocktailbar). Plain jsonb array of strings, editable
-- per event like the room checklist.
alter table public.events add column if not exists sponsor_categories jsonb not null default '[]'::jsonb;

create table if not exists public.sponsorships (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  category text not null,
  sponsor_name text not null,
  email text,
  phone text,
  notes text,
  status text not null default 'offered' check (status in ('offered', 'confirmed', 'declined')),
  created_at timestamptz not null default now()
);

alter table public.sponsorships enable row level security;

-- Same shape as registrations: anyone can offer to sponsor a published event, only staff sees the list.
drop policy if exists "sponsorships_public_insert" on public.sponsorships;
create policy "sponsorships_public_insert" on public.sponsorships for insert
  with check (exists (select 1 from public.events e where e.id = event_id and e.status = 'published'));

drop policy if exists "sponsorships_staff_select" on public.sponsorships;
create policy "sponsorships_staff_select" on public.sponsorships for select
  using (auth.role() = 'authenticated');

drop policy if exists "sponsorships_staff_update" on public.sponsorships;
create policy "sponsorships_staff_update" on public.sponsorships for update
  using (auth.role() = 'authenticated');

drop policy if exists "sponsorships_staff_delete" on public.sponsorships;
create policy "sponsorships_staff_delete" on public.sponsorships for delete
  using (auth.role() = 'authenticated');
