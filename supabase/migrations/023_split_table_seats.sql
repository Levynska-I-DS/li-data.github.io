-- 023_split_table_seats.sql
-- Requested 29.09.2026: a party may be spread over several tables.
-- Example: 9 guests, only 8 seats left at "Tisch 1" -> 8 at Tisch 1 + 1 at Tisch 2.
-- And when all adult tables are fully booked, guests can still register and get
-- "freie Platzwahl" (free seating at the other, non-reserved tables).
--
-- registrations.table_seats: [{"table_id":"...","seats":8},{"table_id":"...","seats":1}]
--   registrations.table_id stays = the first (main) table, for backward compatibility.
-- registrations.free_seating_count: how many persons of this party got no reserved
--   table seat (all tables full) -> free seating.
--
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.registrations add column if not exists table_seats jsonb;
alter table public.registrations add column if not exists free_seating_count integer;

-- Occupancy: rows with table_seats count exactly the booked seats per table;
-- older rows (only table_id) keep the old logic (guests minus Kindertisch children).
create or replace function public.get_table_occupancy(p_event_id uuid)
returns table(table_id text, occupied bigint)
language sql
stable
security definer
set search_path = public
as $BODY$
  with confirmed as (
    select r.*
    from public.registrations r
    join public.events e on e.id = r.event_id
    where r.event_id = p_event_id
      and e.status = 'published'
      and r.status = 'confirmed'
  ),
  split as (
    select s.value->>'table_id' as table_id, (s.value->>'seats')::bigint as seats
    from confirmed c, jsonb_array_elements(c.table_seats) s
    where c.table_seats is not null and jsonb_typeof(c.table_seats) = 'array'
  ),
  legacy as (
    select c.table_id, (c.guests_count - coalesce(kc.kindertisch_count, 0))::bigint as seats
    from confirmed c
    left join (
      select registration_id, count(*) as kindertisch_count
      from public.registration_children
      where at_kindertisch = true
      group by registration_id
    ) kc on kc.registration_id = c.id
    where c.table_id is not null
      and (c.table_seats is null or jsonb_typeof(c.table_seats) <> 'array')
  )
  select table_id, sum(seats)::bigint as occupied
  from (select * from split union all select * from legacy) x
  where table_id is not null
  group by table_id;
$BODY$;

grant execute on function public.get_table_occupancy(uuid) to anon, authenticated;
