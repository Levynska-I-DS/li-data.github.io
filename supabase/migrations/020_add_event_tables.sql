-- 020_add_event_tables.sql
-- Table/seat selection, requested 28.09.2026: guests choose a specific table
-- for their whole registration (family/party), not per person. Tables are
-- defined per event (capacity can differ between events/venues), and are
-- only shown to guests when the organizer turns this on for that event.
--
-- Design note: this mirrors the existing "rooms" feature (events.rooms
-- jsonb) instead of a separate relational table -- same precedent already
-- used elsewhere in this schema, and much simpler than a full table+RLS set.
-- Each entry in events.tables looks like: {"id": "...", "name": "...", "capacity": 8}
-- where "id" is a random string generated in the browser (crypto.randomUUID()),
-- stable across renames, and referenced by registrations.table_id as plain
-- text (no foreign key -- same as how rooms are just referenced by name).
--
-- Capacity visibility problem: an anonymous guest filling out the
-- registration form needs to know how many seats are already taken at each
-- table, but the "registrations" table has no public SELECT policy (only
-- staff can read it -- see 001_init.sql, registrations_staff_select). Adding
-- a public SELECT policy would expose every column (names, emails, phone
-- numbers) to anyone, since row-level security policies can't restrict which
-- columns are visible. Instead, this migration adds a narrow SECURITY
-- DEFINER function that returns ONLY the aggregated occupied-seats-per-table
-- counts for a published event -- no names, no personal data, nothing per
-- registration.
--
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

-- events.has_seating: per-event flag, mirrors has_kindertisch -- only events
-- where this is true show the table picker in the registration form, and
-- only these events get a "Tische verwalten" editor in the admin form.
alter table public.events add column if not exists has_seating boolean not null default false;

-- events.tables: the list of tables for this event, e.g.
-- [{"id":"a1b2c3","name":"Tisch 1","capacity":8}, ...]
alter table public.events add column if not exists tables jsonb not null default '[]'::jsonb;

-- registrations.table_id: the chosen table's "id" (from events.tables) for
-- this whole registration/party. Plain text, not a foreign key -- same
-- lack of relational integrity as the existing "rooms" feature. Nullable --
-- not every event has seating enabled, and stays nullable for safety
-- (e.g. rows created before this feature existed).
alter table public.registrations add column if not exists table_id text;

-- get_table_occupancy: returns how many confirmed seats are already taken
-- at each table for a given (published) event, so the registration form can
-- show "Tisch 3 (2 von 8 Plätzen frei)" to anonymous guests without ever
-- exposing who is sitting there. Only confirmed registrations count against
-- capacity (waitlisted guests aren't seated yet).
--
-- Bug fixed 28.09.2026: guests_count is the WHOLE party (adults + children),
-- but a child marked at_kindertisch actually sits at the separate children's
-- table, not at the family's chosen table -- counting them there overstated
-- occupancy and made tables look full sooner than they really were. Now
-- subtracted per registration via a left join on registration_children.
create or replace function public.get_table_occupancy(p_event_id uuid)
returns table(table_id text, occupied bigint)
language sql
stable
security definer
set search_path = public
as $BODY$
  select
    r.table_id,
    sum(r.guests_count - coalesce(kc.kindertisch_count, 0))::bigint as occupied
  from public.registrations r
  join public.events e on e.id = r.event_id
  left join (
    select registration_id, count(*) as kindertisch_count
    from public.registration_children
    where at_kindertisch = true
    group by registration_id
  ) kc on kc.registration_id = r.id
  where r.event_id = p_event_id
    and e.status = 'published'
    and r.table_id is not null
    and r.status = 'confirmed'
  group by r.table_id;
$BODY$;

grant execute on function public.get_table_occupancy(uuid) to anon, authenticated;
