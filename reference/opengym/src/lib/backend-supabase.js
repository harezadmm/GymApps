// backend.js over Supabase: one row in public.user_state, guarded by RLS.
//
// The only non-obvious piece is push(). A plain UPDATE would happily overwrite a row another
// device wrote while this one was offline, so the write goes through the push_state() RPC
// (supabase/migrations/0002_push_state.sql), which compares the caller's baseRev with the row's
// rev inside the transaction and refuses when they disagree — the same 409-and-hand-back-the-
// document dance openGym's server did. The caller then merges with sync-merge.js and pushes
// again. Nothing here decides how to merge; that is the store's job.
import { NotSignedIn } from './backend.js'
import { supabase } from './supabase.js'

const TABLE = 'user_state'

async function db() {
  const sb = supabase()
  if (!sb) throw new Error('Supabase is not configured — set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY')
  const { data: { session } } = await sb.auth.getSession()
  if (!session) throw new NotSignedIn()
  return sb
}

// PostgREST answers "no rows" for .single() with PGRST116. For a brand-new account that is not
// an error: the row appears on the first push.
const noRow = error => error && (error.code === 'PGRST116' || /no rows/i.test(error.message || ''))

export const backendSupabase = {
  /** Cheap poll: just the revision, so an unchanged server costs one small round trip. */
  async getRev() {
    const sb = await db()
    const { data, error } = await sb.from(TABLE).select('rev').maybeSingle()
    if (error && !noRow(error)) throw error
    return data ? Number(data.rev) : null
  },

  async pull() {
    const sb = await db()
    const { data, error } = await sb.from(TABLE).select('rev, state').maybeSingle()
    if (error && !noRow(error)) throw error
    return data ? { rev: Number(data.rev), state: data.state } : null
  },

  /**
   * @param {number|null} baseRev revision this device last saw; null forces the write through
   *   (used by "adopt this device's copy", exactly like openGym's force flag).
   */
  async push(baseRev, state) {
    const sb = await db()
    const { data, error } = await sb.rpc('push_state', {
      p_base_rev: baseRev == null ? null : Number(baseRev),
      p_state: state,
    })
    if (error) throw error
    // The function returns a one-row table.
    const row = Array.isArray(data) ? data[0] : data
    if (!row) throw new Error('push_state returned nothing')
    return row.ok
      ? { ok: true, rev: Number(row.rev) }
      : { ok: false, rev: Number(row.rev), state: row.state }
  },
}

export default backendSupabase
