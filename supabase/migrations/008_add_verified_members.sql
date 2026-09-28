-- Staff-maintained registry of community members Iryna has personally verified
-- (via a third-party check, e.g. the membership office), independent of any
-- single event registration. Self-declared member_status on registrations
-- stays as-is; this table lets staff mark a person as confirmed once and
-- reuse that across all future events (matched by email in participants.html).
create table if not exists public.verified_members (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text not null,
  phone text,
  notes text,
  verified_at timestamptz not null default now(),
  verified_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create unique index if not exists verified_members_email_idx
  on public.verified_members (lower(email));

alter table public.verified_members enable row level security;

drop policy if exists "verified_members_staff_all" on public.verified_members;
create policy "verified_members_staff_all" on public.verified_members
  for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');
