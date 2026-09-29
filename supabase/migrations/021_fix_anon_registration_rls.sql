-- 021: Fix "new row violates row-level security policy" for anonymous visitors.
--
-- Problem: the insert policies on registration_children and registration_order_items
-- check "exists (select 1 from public.registrations ...)". That subquery runs with the
-- visitor's own rights, and anonymous visitors have no SELECT policy on registrations
-- (on purpose - names/emails must stay private). So for anon the subquery never finds
-- the just-created registration and the insert is rejected.
-- Logged-in staff did not notice, because staff CAN select registrations.
--
-- Fix: a narrow SECURITY DEFINER helper that answers only "yes/no: does this
-- registration belong to a published event" - no other data leaves the function.

create or replace function public.registration_event_is_published(p_registration_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.registrations r
    join public.events e on e.id = r.event_id
    where r.id = p_registration_id and e.status = 'published'
  );
$$;

revoke all on function public.registration_event_is_published(uuid) from public;
grant execute on function public.registration_event_is_published(uuid) to anon, authenticated;

drop policy if exists "registration_children_public_insert" on public.registration_children;
create policy "registration_children_public_insert" on public.registration_children for insert
  with check (public.registration_event_is_published(registration_id));

drop policy if exists "registration_order_items_public_insert" on public.registration_order_items;
create policy "registration_order_items_public_insert" on public.registration_order_items for insert
  with check (public.registration_event_is_published(registration_id));
