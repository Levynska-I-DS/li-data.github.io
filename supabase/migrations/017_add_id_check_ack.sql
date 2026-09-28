-- 017_add_id_check_ack.sql
-- Security requirement (28.09.2026): non-members (member_status = 'no') must send a
-- copy of their ID/passport to sicherheit@irgw.de for the security check, by the
-- event's registration deadline, and must actively agree to this in the form. This
-- records that acknowledgement so staff can see, per registration, who still owes
-- an ID copy -- derived together with the existing member_status column, no new
-- lookup needed.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.registrations add column if not exists id_check_ack boolean;
