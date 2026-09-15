// The Supabase client, and where its session is kept.
//
// On the web the default (localStorage) is right. In the APK it is not: a WebView's localStorage
// is ordinary app storage, and a refresh token is the one thing in this app worth protecting
// (NFR-6 — "token disimpan di secure storage Android"). openGym already depends on
// @aparajita/capacitor-secure-storage for exactly this, so the APK reuses it.
//
// supabase-js accepts an async storage adapter, which is what lets the Keystore-backed plugin
// stand in for localStorage without any other code noticing.
import { createClient } from '@supabase/supabase-js'
import { MOBILE } from './mobile.js'

const URL = import.meta.env?.VITE_SUPABASE_URL
const ANON = import.meta.env?.VITE_SUPABASE_ANON_KEY

/** True when the build was given a project to talk to. Lets the UI say something useful instead of throwing. */
export const supabaseConfigured = () => Boolean(URL && ANON)

// Loaded lazily: a web build must not pull the Capacitor plugin into its bundle, and a test
// must not need it installed at all.
function secureStorageAdapter() {
  let plugin = null
  const load = async () => plugin || (plugin = (await import('@aparajita/capacitor-secure-storage')).SecureStorage)
  return {
    async getItem(key) {
      try { const v = await (await load()).get(key, true, false); return typeof v === 'string' ? v : null }
      catch { return null }
    },
    async setItem(key, value) {
      try { await (await load()).set(key, value, true, false) } catch { /* a locked keystore must not break sign-in */ }
    },
    async removeItem(key) {
      try { await (await load()).remove(key) } catch { /* already gone is the outcome we wanted */ }
    },
  }
}

let client = null

/** The one client for the process. Null when the build has no project configured. */
export function supabase() {
  if (client) return client
  if (!supabaseConfigured()) return null
  client = createClient(URL, ANON, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      // No OAuth redirect to read: email + password only (spec §2), and a WebView has no URL bar.
      detectSessionInUrl: false,
      storageKey: 'gymapps.auth',
      ...(MOBILE ? { storage: secureStorageAdapter() } : {}),
    },
  })
  return client
}

/** Test seam: drop the memoised client so a test can build a fresh one. */
export function resetSupabaseClient() { client = null }
