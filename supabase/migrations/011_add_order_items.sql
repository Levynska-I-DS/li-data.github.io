-- 011_add_order_items.sql
-- Pre-orders for extra items at an event (drinks, alcohol, etc.) — the last piece
-- from the original project brief's registration flow. Iryna defines a per-event
-- catalog (name + price); attendees pick quantities while registering.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

-- Per-event catalog: jsonb array of {name, price}, editable like rooms/sponsor_categories.
alter table public.events add column if not exists order_products jsonb not null default '[]'::jsonb;

create table if not exists public.registration_order_items (
  id uuid primary key default gen_random_uuid(),
  registration_id uuid not null references public.registrations(id) on delete cascade,
  product_name text not null,
  unit_price numeric(10,2),
  quantity integer not null default 1 check (quantity > 0),
  created_at timestamptz not null default now()
);

alter table public.registration_order_items enable row level security;

-- Same shape as registration_children: a visitor can add order items to their own
-- registration for a published event; only staff can see/manage the full list.
drop policy if exists "registration_order_items_public_insert" on public.registration_order_items;
create policy "registration_order_items_public_insert" on public.registration_order_items for insert
  with check (exists (
    select 1 from public.registrations r
    join public.events e on e.id = r.event_id
    where r.id = registration_id and e.status = 'published'
  ));

drop policy if exists "registration_order_items_staff_select" on public.registration_order_items;
create policy "registration_order_items_staff_select" on public.registration_order_items for select
  using (auth.role() = 'authenticated');

drop policy if exists "registration_order_items_staff_update" on public.registration_order_items;
create policy "registration_order_items_staff_update" on public.registration_order_items for update
  using (auth.role() = 'authenticated');

drop policy if exists "registration_order_items_staff_delete" on public.registration_order_items;
create policy "registration_order_items_staff_delete" on public.registration_order_items for delete
  using (auth.role() = 'authenticated');
