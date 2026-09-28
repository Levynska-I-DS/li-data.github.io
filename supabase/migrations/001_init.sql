-- 001_init.sql
-- Event Manager: MVP base tables (profiles, events, registrations, expenses, receipts).
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

-- 1. User profiles (extends auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'event_manager' check (role in ('admin','event_manager')),
  created_at timestamptz not null default now()
);

-- Automatically creates a profile row when a new user signs up in auth.users
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. Events
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  location text,
  status text not null default 'draft' check (status in ('draft','published','closed')),
  capacity integer,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Registrations
create table if not exists public.registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  full_name text not null,
  email text not null,
  phone text,
  guests_count integer not null default 1,
  notes text,
  status text not null default 'confirmed' check (status in ('confirmed','cancelled','waitlist')),
  created_at timestamptz not null default now()
);

-- 4. Expenses
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  description text not null,
  category text,
  amount numeric(10,2) not null,
  paid_by text,
  expense_date date not null default current_date,
  status text not null default 'pending' check (status in ('pending','approved','paid')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- 5. Receipts
create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  file_path text not null,
  uploaded_by uuid references public.profiles(id),
  uploaded_at timestamptz not null default now()
);

-- === Row Level Security ===
alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.registrations enable row level security;
alter table public.expenses enable row level security;
alter table public.receipts enable row level security;

-- profiles: a user can see and edit only their own row
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- events: published events are visible to everyone; authenticated staff can see and change everything
create policy "events_public_read_published" on public.events for select using (status = 'published');
create policy "events_staff_all" on public.events for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- registrations: a visitor can register for a published event; only staff can see the list
create policy "registrations_public_insert" on public.registrations for insert
  with check (exists (select 1 from public.events e where e.id = event_id and e.status = 'published'));
create policy "registrations_staff_select" on public.registrations for select using (auth.role() = 'authenticated');
create policy "registrations_staff_update" on public.registrations for update using (auth.role() = 'authenticated');

-- expenses and receipts: fully private, staff only
create policy "expenses_staff_all" on public.expenses for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "receipts_staff_all" on public.receipts for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- === Storage: private bucket for receipts ===
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

create policy "receipts_bucket_staff_all" on storage.objects for all
  using (bucket_id = 'receipts' and auth.role() = 'authenticated')
  with check (bucket_id = 'receipts' and auth.role() = 'authenticated');
