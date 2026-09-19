// Run locally only. Never import this file into the browser bundle.
// node --env-file=.env.admin.local scripts/manage-user.mjs AUTH_USER_UUID
import { createClient } from '@supabase/supabase-js';

const id = process.argv[2];
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, AUTH_NEW_EMAIL, AUTH_NEW_PASSWORD } = process.env;
if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id || '')) {
  console.error('Pass the user UUID from Supabase Authentication > Users.');
  process.exit(1);
}
if (!SUPABASE_URL?.startsWith('https://') || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in a private local environment file.');
  process.exit(1);
}
if (!AUTH_NEW_EMAIL && !AUTH_NEW_PASSWORD) {
  console.error('Set AUTH_NEW_EMAIL and/or AUTH_NEW_PASSWORD.');
  process.exit(1);
}
if (AUTH_NEW_PASSWORD && AUTH_NEW_PASSWORD.length < 12) {
  console.error('Use a unique password with at least 12 characters.');
  process.exit(1);
}
if (AUTH_NEW_EMAIL && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(AUTH_NEW_EMAIL)) {
  console.error('AUTH_NEW_EMAIL must be a valid email address.');
  process.exit(1);
}
const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false }
});
const updates = {};
if (AUTH_NEW_EMAIL) {
  updates.email = AUTH_NEW_EMAIL.trim().toLowerCase();
  updates.email_confirm = true;
}
if (AUTH_NEW_PASSWORD) updates.password = AUTH_NEW_PASSWORD;
const { error } = await client.auth.admin.updateUserById(id, updates);
if (error) {
  console.error('Account was not updated:', error.message);
  process.exit(1);
}
console.log('Account updated through Supabase Auth. Sign out on all devices and sign in with the new credentials.');
console.log('Existing access JWTs can remain valid until expiry. Revoke student verification immediately if access must stop.');
console.log('Delete AUTH_NEW_PASSWORD from your local environment file after use. Never commit secrets.');
