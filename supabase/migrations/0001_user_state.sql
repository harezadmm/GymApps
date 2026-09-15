-- GymApps — satu dokumen JSON per pengguna (skema `S` openGym).
-- Mengganti server Node openGym; lihat spec §4.

create table if not exists public.user_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  rev        bigint not null default 0,
  state      jsonb  not null,
  updated_at timestamptz not null default now()
);

alter table public.user_state enable row level security;

-- Satu pengguna hanya bisa membaca dan menulis barisnya sendiri (NFR-6).
drop policy if exists "own row" on public.user_state;
create policy "own row" on public.user_state
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
