// supabase/functions/notify-registration/index.ts
//
// Fires on every new registration (Supabase Database Webhook on INSERT into
// public.registrations) and sends TWO emails:
//   1. To Iryna (admin) — as before: new-registration alert with a link to
//      the participant list.
//   2. To the registrant themselves — a confirmation of their registration,
//      in the language they used on the form (registrations.lang), with the
//      event details and, for non-members, a reminder of the fee/ID-check
//      deadline they already agreed to.
//
// Triggered by a Supabase Database Webhook (Database -> Webhooks in Studio)
// on INSERT into public.registrations. See the architecture doc / setup
// notes for the manual steps needed in the Supabase dashboard and at
// resend.com — this function alone does nothing until that wiring exists.
//
// Env vars used:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  -> auto-provided by Supabase for
//                                               every Edge Function, no setup needed.
//   RESEND_API_KEY                           -> set yourself: Studio -> Edge
//                                               Functions -> notify-registration
//                                               -> Secrets.
//   NOTIFY_WEBHOOK_SECRET                    -> set yourself (any random string).
//                                               Must match the "Authorization"
//                                               header you configure on the
//                                               Database Webhook, so random
//                                               internet requests can't trigger
//                                               emails.
//   NOTIFY_TO_EMAIL                          -> optional override; defaults to
//                                               iryna.levynska@li-data.de.
//   RESEND_FROM_EMAIL                        -> optional override for the
//                                               "from" address used for BOTH
//                                               emails. Defaults to
//                                               'Event Manager <onboarding@resend.dev>'.
//                                               IMPORTANT: Resend's shared
//                                               onboarding@resend.dev address
//                                               can only deliver to the email
//                                               address of the Resend account
//                                               owner (i.e. only the admin
//                                               email above will actually
//                                               arrive). To send the
//                                               confirmation to real
//                                               registrants, verify your own
//                                               sending domain in Resend
//                                               (Resend -> Domains, e.g.
//                                               mail.li-data.de) and set this
//                                               to an address on that domain,
//                                               e.g. 'IRGW Events <events@li-data.de>'.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const WEBHOOK_SECRET = Deno.env.get('NOTIFY_WEBHOOK_SECRET')!;
const TO_EMAIL = Deno.env.get('NOTIFY_TO_EMAIL') || 'iryna.levynska@li-data.de';
const FROM_EMAIL = Deno.env.get('RESEND_FROM_EMAIL') || 'Event Manager <onboarding@resend.dev>';

const MEMBER_LABELS: Record<string, string> = { yes: 'Ja', no: 'Nein', unknown: 'Weiß nicht' };

const LOCALE: Record<string, string> = { de: 'de-DE', en: 'en-GB', ru: 'ru-RU' };

function formatDate(iso: string | null, lang: string, style: 'full' | 'long'): string {
  if (!iso) return '—';
  const locale = LOCALE[lang] || 'de-DE';
  return new Intl.DateTimeFormat(locale, {
    timeZone: 'Europe/Berlin',
    dateStyle: style,
    timeStyle: style === 'full' ? 'short' : undefined,
  }).format(new Date(iso));
}

// Fee/ID-check reminder block for non-members, in the registrant's language.
// Mirrors the consent text they already agreed to on the registration form.
function feeIdBlock(lang: string, deadlineIso: string | null, amount: number | null): string {
  const hasDeadline = !!deadlineIso;
  const deadlineStr = hasDeadline ? formatDate(deadlineIso, lang, 'long') : null;
  const amountStr = amount != null ? amount.toFixed(2) : null;

  if (lang === 'en') {
    const by = hasDeadline ? `by ${deadlineStr} at the latest` : 'before the event';
    return amountStr
      ? `<p>As a reminder: please transfer the participation fee of <strong>${amountStr} €</strong> and send a copy of your ID card or passport for the security check to <a href="mailto:sicherheit@irgw.de">sicherheit@irgw.de</a> — both ${by}.</p>`
      : `<p>As a reminder: please send a copy of your ID card or passport for the security check to <a href="mailto:sicherheit@irgw.de">sicherheit@irgw.de</a> — ${by}.</p>`;
  }
  if (lang === 'ru') {
    const by = hasDeadline ? `до ${deadlineStr}` : 'до начала мероприятия';
    return amountStr
      ? `<p>Напоминаем: пожалуйста, переведите организационный взнос <strong>${amountStr} €</strong> и отправьте копию удостоверения личности или загранпаспорта для проверки службой безопасности на <a href="mailto:sicherheit@irgw.de">sicherheit@irgw.de</a> — оба пункта ${by}.</p>`
      : `<p>Напоминаем: пожалуйста, отправьте копию удостоверения личности или загранпаспорта для проверки службой безопасности на <a href="mailto:sicherheit@irgw.de">sicherheit@irgw.de</a> — ${by}.</p>`;
  }
  const by = hasDeadline ? `bis spätestens ${deadlineStr}` : 'vor der Veranstaltung';
  return amountStr
    ? `<p>Zur Erinnerung: Bitte überweisen Sie den Teilnahmebeitrag von <strong>${amountStr} €</strong> und senden Sie eine Kopie Ihres Ausweises oder Reisepasses zur Sicherheitskontrolle an <a href="mailto:sicherheit@irgw.de">sicherheit@irgw.de</a> — beides ${by}.</p>`
    : `<p>Zur Erinnerung: Bitte senden Sie eine Kopie Ihres Ausweises oder Reisepasses zur Sicherheitskontrolle an <a href="mailto:sicherheit@irgw.de">sicherheit@irgw.de</a> — ${by}.</p>`;
}

function buildParticipantEmail(ctx: {
  lang: string;
  fullName: string;
  title: string;
  startsAt: string | null;
  location: string | null;
  guestsCount: number;
  isNonMember: boolean;
  registrationDeadline: string | null;
  feeAmountCharged: number | null;
}): { subject: string; html: string } {
  const { lang, fullName, title, startsAt, location, guestsCount, isNonMember, registrationDeadline, feeAmountCharged } = ctx;
  const dateStr = formatDate(startsAt, lang, 'full');
  const loc = location || '—';
  const reminder = isNonMember ? feeIdBlock(lang, registrationDeadline, feeAmountCharged) : '';

  if (lang === 'en') {
    return {
      subject: `Registration confirmed: ${title}`,
      html: `
        <p>Dear ${fullName},</p>
        <p>thank you for registering for <strong>${title}</strong>.</p>
        <ul>
          <li>📅 <strong>Date:</strong> ${dateStr}</li>
          <li>📍 <strong>Location:</strong> ${loc}</li>
          <li>👥 <strong>Number of guests:</strong> ${guestsCount}</li>
        </ul>
        ${reminder}
        <p>If you have any questions, just reply to this email or write to <a href="mailto:grinblat@irgw.de">grinblat@irgw.de</a>.</p>
        <p>We look forward to seeing you!<br>IRGW – Event Manager</p>
      `,
    };
  }
  if (lang === 'ru') {
    return {
      subject: `Регистрация подтверждена: ${title}`,
      html: `
        <p>Здравствуйте, ${fullName}!</p>
        <p>спасибо за регистрацию на «${title}».</p>
        <ul>
          <li>📅 <strong>Дата:</strong> ${dateStr}</li>
          <li>📍 <strong>Место:</strong> ${loc}</li>
          <li>👥 <strong>Количество человек:</strong> ${guestsCount}</li>
        </ul>
        ${reminder}
        <p>Если у вас есть вопросы, просто ответьте на это письмо или напишите на <a href="mailto:grinblat@irgw.de">grinblat@irgw.de</a>.</p>
        <p>До встречи!<br>IRGW – Event Manager</p>
      `,
    };
  }
  return {
    subject: `Anmeldebestätigung: ${title}`,
    html: `
      <p>Liebe/r ${fullName},</p>
      <p>vielen Dank für Ihre Anmeldung zu <strong>${title}</strong>.</p>
      <ul>
        <li>📅 <strong>Termin:</strong> ${dateStr}</li>
        <li>📍 <strong>Ort:</strong> ${loc}</li>
        <li>👥 <strong>Anzahl Personen:</strong> ${guestsCount}</li>
      </ul>
      ${reminder}
      <p>Bei Fragen antworten Sie einfach auf diese E-Mail oder schreiben Sie an <a href="mailto:grinblat@irgw.de">grinblat@irgw.de</a>.</p>
      <p>Wir freuen uns auf Sie!<br>IRGW – Event Manager</p>
    `,
  };
}

async function sendEmail(to: string, subject: string, html: string): Promise<{ ok: boolean; error?: string }> {
  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: FROM_EMAIL, to, subject, html }),
  });
  if (!resendRes.ok) {
    const errText = await resendRes.text();
    return { ok: false, error: errText };
  }
  return { ok: true };
}

Deno.serve(async (req) => {
  // Simple shared-secret check so this endpoint can't be triggered by anyone
  // who finds the URL. The Database Webhook is configured to send this same
  // value as a custom header (see setup notes).
  if (req.headers.get('authorization') !== `Bearer ${WEBHOOK_SECRET}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const payload = await req.json();
  if (payload.type !== 'INSERT' || payload.table !== 'registrations') {
    return new Response('Ignored (not a registration insert)', { status: 200 });
  }

  const registration = payload.record;
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: event } = await supabase
    .from('events')
    .select('title, slug, capacity, starts_at, location, registration_deadline')
    .eq('id', registration.event_id)
    .single();

  const { count: confirmedCount } = await supabase
    .from('registrations')
    .select('id', { count: 'exact', head: true })
    .eq('event_id', registration.event_id)
    .eq('status', 'confirmed');

  const eventTitle = event?.title || 'Unbekannte Veranstaltung';
  const capacityLine = event?.capacity
    ? `${confirmedCount ?? '?'} / ${event.capacity} bestätigt`
    : `${confirmedCount ?? '?'} bestätigt (kein Limit)`;

  // 1. Admin alert (unchanged behaviour from before).
  const adminSubject = `Neue Anmeldung: ${eventTitle} (${capacityLine})`;
  const adminHtml = `
    <p>Neue Anmeldung für <strong>${eventTitle}</strong>:</p>
    <ul>
      <li><strong>Name:</strong> ${registration.full_name}</li>
      <li><strong>E-Mail:</strong> ${registration.email}</li>
      <li><strong>Telefon:</strong> ${registration.phone || '—'}</li>
      <li><strong>Mitglied:</strong> ${MEMBER_LABELS[registration.member_status] ?? '—'}</li>
      <li><strong>Personen:</strong> ${registration.guests_count}</li>
    </ul>
    <p>Aktueller Stand: <strong>${capacityLine}</strong></p>
    <p><a href="https://li-data.de/app/events/participants.html?event=${event?.slug ?? ''}">Zur Teilnehmerliste</a></p>
  `;
  const adminResult = await sendEmail(TO_EMAIL, adminSubject, adminHtml);
  if (!adminResult.ok) {
    console.error('Resend error (admin email):', adminResult.error);
  }

  // 2. Participant confirmation, best-effort: a failure here must not stop
  // the admin alert above from having been sent, and must not turn the
  // registration itself into an error for the visitor (the webhook fires
  // after the row is already saved).
  let participantResult: { ok: boolean; error?: string } = { ok: true };
  if (registration.email) {
    const { subject, html } = buildParticipantEmail({
      lang: registration.lang || 'de',
      fullName: registration.full_name,
      title: eventTitle,
      startsAt: event?.starts_at ?? null,
      location: event?.location ?? null,
      guestsCount: registration.guests_count,
      isNonMember: registration.member_status === 'no',
      registrationDeadline: event?.registration_deadline ?? null,
      feeAmountCharged: registration.fee_amount_charged ?? null,
    });
    participantResult = await sendEmail(registration.email, subject, html);
    if (!participantResult.ok) {
      console.error('Resend error (participant email):', participantResult.error);
    }
  }

  if (!adminResult.ok && !participantResult.ok) {
    return new Response('Registration saved, but both emails failed.', { status: 502 });
  }
  if (!adminResult.ok || !participantResult.ok) {
    return new Response('Registration saved; one of the two emails failed (see function logs).', { status: 200 });
  }
  return new Response('OK', { status: 200 });
});
