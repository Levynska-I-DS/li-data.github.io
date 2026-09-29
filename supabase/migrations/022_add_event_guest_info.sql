-- 022: Structured guest information shown on the event page BEFORE the registration form
-- (step 1: read info & conditions -> button "Zur Anmeldung" -> step 2: form).
-- Separate fields (not one big text) so the same data can later be reused in e-mails,
-- e.g. bank details only for non-members.
-- ends_at already exists since 001 -> used for the time range "09:30 – 13:00 Uhr".

alter table public.events add column if not exists audience_info     text; -- Wer kann teilnehmen?
alter table public.events add column if not exists program_info      text; -- Was erwartet euch? (one line = one bullet)
alter table public.events add column if not exists meal_info         text; -- Verpflegung: optional details
alter table public.events add column if not exists payment_recipient text; -- Kontoinhaber
alter table public.events add column if not exists payment_iban      text;
alter table public.events add column if not exists payment_bic       text;
alter table public.events add column if not exists payment_reference text; -- Verwendungszweck
alter table public.events add column if not exists payment_paypal    text; -- PayPal e-mail
alter table public.events add column if not exists security_email    text; -- ID copy goes here (default in UI: sicherheit@irgw.de)
alter table public.events add column if not exists security_info     text; -- extra note for the security check
alter table public.events add column if not exists contact_email     text; -- "Fragen?"
alter table public.events add column if not exists accent_theme      text not null default 'rosa'; -- colour accent of the public page (rosa/blau/gold/gruen/neutral)

-- Sponsoring category "Salat-Dekoration" renamed to "Dekoration" (sounded unclear in German).
-- Renames it in every event's list and in already submitted sponsorship offers.
update public.events
set sponsor_categories = (
  select coalesce(jsonb_agg(case when c.value = to_jsonb('Salat-Dekoration'::text) then to_jsonb('Dekoration'::text) else c.value end order by c.ord), '[]'::jsonb)
  from jsonb_array_elements(sponsor_categories) with ordinality as c(value, ord)
)
where sponsor_categories @> '["Salat-Dekoration"]'::jsonb;

update public.sponsorships set category = 'Dekoration' where category = 'Salat-Dekoration';
