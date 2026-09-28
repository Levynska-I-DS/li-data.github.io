-- 018_add_registration_lang.sql
-- Records which language (DE/EN/RU) a registrant used on the registration
-- form, so the confirmation email (notify-registration Edge Function) can
-- be sent in that same language instead of always German.
-- How to apply: Supabase Studio -> SQL Editor -> New query -> paste the whole file -> Run.

alter table public.registrations add column if not exists lang text not null default 'de';
alter table public.registrations drop constraint if exists registrations_lang_check;
alter table public.registrations add constraint registrations_lang_check
  check (lang in ('de', 'en', 'ru'));
