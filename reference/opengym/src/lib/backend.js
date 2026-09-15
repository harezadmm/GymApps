// The one seam between the app and wherever the account's document lives.
//
// openGym talked to its own Node server through api() in a dozen places. GymApps talks to
// Supabase — but the store should not know that, and the tests should not need a network. So
// everything the store needs is three functions, and the implementation behind them is swapped
// at boot (setBackend) or in a test (setBackend with a fake).
//
// The contract is deliberately the one openGym's server already spoke, because sync-merge.js
// and the store's conflict handling were written against it:
//
//   getRev()              → number | null      the revision the server holds, null when no row yet
//   pull()                → { rev, state } | null
//   push(baseRev, state)  → { ok: true,  rev }
//                         | { ok: false, rev, state }   server moved on — merge and push again
//
// `baseRev` is the revision the device last saw. A push carrying a stale one is refused rather
// than silently overwriting the copy another device wrote, which is the whole reason FR-A4
// ("two devices offline, nothing lost") can be met.

/** Thrown when a call needs a signed-in session and there isn't one. */
export class NotSignedIn extends Error {
  constructor() { super('not signed in'); this.name = 'NotSignedIn' }
}

const missing = name => () => { throw new Error(`backend not configured: ${name}()`) }

let impl = { getRev: missing('getRev'), pull: missing('pull'), push: missing('push') }

/** Install the live implementation (backend-supabase.js) or a fake in tests. */
export function setBackend(next) {
  if (!next || typeof next.getRev !== 'function' || typeof next.pull !== 'function' || typeof next.push !== 'function') {
    throw new Error('backend must implement getRev, pull and push')
  }
  impl = next
}

export const getRev = () => impl.getRev()
export const pull = () => impl.pull()
export const push = (baseRev, state) => impl.push(baseRev, state)
