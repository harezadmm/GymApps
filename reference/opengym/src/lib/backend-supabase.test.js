import { beforeEach, describe, expect, it, vi } from 'vitest'

// A fake Supabase client. Only the three shapes backend-supabase.js touches exist here:
// auth.getSession(), from(...).select(...).maybeSingle(), and rpc(). Anything else is a
// deliberate hole — a call this module should not be making.
const fake = vi.hoisted(() => {
  const state = { session: { user: { id: 'u1' } }, row: null, rpc: null, calls: [] }
  state.client = {
    auth: { getSession: async () => ({ data: { session: state.session } }) },
    from(table) {
      state.calls.push(['from', table])
      return { select: cols => ({ maybeSingle: async () => (state.calls.push(['select', cols]), state.row) }) }
    },
    async rpc(name, args) {
      state.calls.push(['rpc', name, args])
      return state.rpc
    },
  }
  return state
})
vi.mock('./supabase.js', () => ({ supabase: () => fake.client, supabaseConfigured: () => true }))

const { backendSupabase } = await import('./backend-supabase.js')
const { NotSignedIn } = await import('./backend.js')

beforeEach(() => {
  fake.session = { user: { id: 'u1' } }
  fake.row = { data: null, error: null }
  fake.rpc = { data: null, error: null }
  fake.calls = []
})

describe('getRev', () => {
  it('is null for an account whose row does not exist yet', async () => {
    expect(await backendSupabase.getRev()).toBe(null)
  })

  it('reads the revision the server holds', async () => {
    fake.row = { data: { rev: 7 }, error: null }
    expect(await backendSupabase.getRev()).toBe(7)
  })

  it('treats PGRST116 as "no row", not as a failure', async () => {
    fake.row = { data: null, error: { code: 'PGRST116', message: 'JSON object requested, multiple (or no) rows returned' } }
    expect(await backendSupabase.getRev()).toBe(null)
  })

  it('surfaces a real error rather than pretending the account is empty', async () => {
    fake.row = { data: null, error: { code: '42501', message: 'permission denied' } }
    await expect(backendSupabase.getRev()).rejects.toMatchObject({ code: '42501' })
  })
})

describe('pull', () => {
  it('is null before the first push', async () => {
    expect(await backendSupabase.pull()).toBe(null)
  })

  it('returns the revision and the document together', async () => {
    fake.row = { data: { rev: 3, state: { workouts: [{ id: 'w1' }] } }, error: null }
    expect(await backendSupabase.pull()).toEqual({ rev: 3, state: { workouts: [{ id: 'w1' }] } })
  })
})

describe('push', () => {
  it('sends the base revision the device last saw', async () => {
    fake.rpc = { data: [{ ok: true, rev: 4, state: null }], error: null }
    const res = await backendSupabase.push(3, { workouts: [] })
    expect(res).toEqual({ ok: true, rev: 4 })
    expect(fake.calls).toContainEqual(['rpc', 'push_state', { p_base_rev: 3, p_state: { workouts: [] } }])
  })

  it('passes null through as a forced write (adopt this device\'s copy)', async () => {
    fake.rpc = { data: [{ ok: true, rev: 1, state: null }], error: null }
    await backendSupabase.push(null, { workouts: [] })
    expect(fake.calls).toContainEqual(['rpc', 'push_state', { p_base_rev: null, p_state: { workouts: [] } }])
  })

  // The case FR-A4 exists for: another device wrote while this one was offline. The push must
  // not win by being last — it comes back refused, carrying the copy to merge with.
  it('hands back the server document when the revision moved on', async () => {
    const server = { workouts: [{ id: 'from-the-other-phone' }] }
    fake.rpc = { data: [{ ok: false, rev: 9, state: server }], error: null }
    expect(await backendSupabase.push(3, { workouts: [] })).toEqual({ ok: false, rev: 9, state: server })
  })

  it('accepts the row whether PostgREST unwraps it or not', async () => {
    fake.rpc = { data: { ok: true, rev: 2, state: null }, error: null }
    expect(await backendSupabase.push(1, {})).toEqual({ ok: true, rev: 2 })
  })

  it('throws when the RPC itself failed', async () => {
    fake.rpc = { data: null, error: { message: 'boom' } }
    await expect(backendSupabase.push(1, {})).rejects.toMatchObject({ message: 'boom' })
  })
})

describe('without a session', () => {
  // Every call needs auth.uid(): RLS has nothing to match on otherwise, and a silent empty
  // answer would look exactly like "your account has no data".
  it.each(['getRev', 'pull'])('%s refuses rather than returning empty', async fn => {
    fake.session = null
    await expect(backendSupabase[fn]()).rejects.toBeInstanceOf(NotSignedIn)
  })

  it('push refuses too', async () => {
    fake.session = null
    await expect(backendSupabase.push(1, {})).rejects.toBeInstanceOf(NotSignedIn)
  })
})
