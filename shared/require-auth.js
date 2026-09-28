// Auth check for private Event Manager pages (and future /app/* modules).
// Redirects to the login page when there is no active session.
import { supabase } from './supabase-client.js';

export async function requireAuth(loginPath = '/app/login.html') {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = loginPath;
    return null;
  }
  return session.user;
}

export async function logout(loginPath = '/app/login.html') {
  await supabase.auth.signOut();
  window.location.href = loginPath;
}
