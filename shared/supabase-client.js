// Shared Supabase client for Event Manager (and future modules: assistant, realestate).
// The anon/publishable key is public by design: data access is restricted by RLS
// policies in the database (see supabase/migrations/001_init.sql), not by keeping this key secret.
// NEVER put a "service_role"/"secret" key here — it bypasses RLS entirely.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://vxckizragmschyerppow.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4Y2tpenJhZ21zY2h5ZXJwcG93Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4OTc3MTksImV4cCI6MjEwNTQ3MzcxOX0.O8VU7sUtuoZfcoHiCl5zYbNBxa84oJjkbibcc_yVHYw';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
