-- 014_add_registrations_staff_delete.sql
-- registrations had insert (public), select (staff) and update (staff) policies
-- from 001_init.sql, but no delete policy -- so staff clicking "Loeschen" in
-- participants.html silently deleted 0 rows (RLS blocks it, but no error is
-- raised; the row just stays). registration_children/registration_order_items
-- already had their own staff-delete policies and cascade from registrations,
-- so this was the one missing piece.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

drop policy if exists "registrations_staff_delete" on public.registrations;
create policy "registrations_staff_delete" on public.registrations for delete
  using (auth.role() = 'authenticated');
