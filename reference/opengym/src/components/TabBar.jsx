import { useLocation, useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { t } from '../lib/i18n.js'
import Icon from './Icon.jsx'

/* Lima tab datar: Workout · Home · Stats · History · Profile (PRD §10, desain
   `REFRENSI/export/04 Home.png`). openGym punya enam slot dengan tombol Start
   bundar di tengah; Liftoff tidak, dan Start-nya hidup di kartu "Sesi berikutnya"
   di Home. Menghapus FAB tidak melanggar target "≤ 4 tap sampai set pertama"
   (PRD §3): Home → Start → lewati berat badan → centang.

   Tab Workout mengurus dua tujuan supaya sesi yang sedang jalan tidak kehilangan
   jalan pulang setelah FAB hilang: saat ada `S.active` ia membuka logger dan
   menyala oranye, selain itu membuka daftar rutinitas. */
const TABS = [
  { k: 'workout', icon: 'dumbbell', to: '/plan',     label: () => t('Workout') },
  { k: 'home',    icon: 'house',    to: '/home',     label: () => t('Home') },
  { k: 'stats',   icon: 'chart',    to: '/stats',    label: () => t('Stats') },
  { k: 'history', icon: 'history',  to: '/history',  label: () => t('History') },
  { k: 'profile', icon: 'person',   to: '/settings', label: () => t('Profile') },
]

// Layar yang tidak punya tab sendiri tetap menyalakan tab induknya, supaya
// bagian bawah layar tidak pernah kosong saat menelusuri ke dalam.
const PARENT = {
  plan: 'workout', workout: 'workout', library: 'workout', muscles: 'stats',
  settings: 'profile', stats: 'stats', history: 'history', home: 'home',
}

export default function TabBar() {
  const nav = useNavigate()
  const loc = useLocation()
  const active = useStore(s => s.S.active)
  const user = useStore(s => s.user)
  const isGuest = useStore(s => s.isGuest())
  if (!user && !isGuest) return null

  const seg = loc.pathname.split('/')[1] || 'home'
  const cur = PARENT[seg] || seg

  return (
    <nav id="tabbar">
      {TABS.map(({ k, icon, to, label }) => {
        const running = k === 'workout' && active
        return (
          <button
            key={k}
            className={(cur === k ? 'on' : '') + (running ? ' rec' : '')}
            aria-current={cur === k ? 'page' : undefined}
            onClick={() => nav(running ? '/workout' : to)}
          >
            <Icon name={icon} />
            <span>{running && cur !== 'workout' ? t('Resume') : label()}</span>
          </button>
        )
      })}
    </nav>
  )
}
