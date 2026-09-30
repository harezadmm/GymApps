-- GymApps — jalankan SEKALI di Supabase SQL Editor.
-- Gabungan dari supabase/migrations/0001, 0002, dan 0003.

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

-- Push dengan cek revisi, meniru `baseRev` openGym (spec §4.2).
--
-- Klien mengirim revisi yang terakhir dilihatnya. Kalau server sudah lebih
-- maju, push ditolak dan dokumen server dikembalikan supaya klien bisa
-- menjalankan sync-merge.js lalu push ulang. Ini yang membuat FR-A4
-- (dua perangkat offline, tidak ada data hilang) bisa dipenuhi.

create or replace function public.push_state(p_base_rev bigint, p_state jsonb)
returns table (ok boolean, rev bigint, state jsonb)
language plpgsql
security invoker
set search_path = public
as $$
declare cur_rev bigint;
begin
  select s.rev into cur_rev from public.user_state s where s.user_id = auth.uid();

  if cur_rev is null then
    insert into public.user_state(user_id, rev, state) values (auth.uid(), 1, p_state);
    return query select true, 1::bigint, p_state;

  elsif p_base_rev is null or p_base_rev = cur_rev then
    update public.user_state
       set rev = cur_rev + 1, state = p_state, updated_at = now()
     where user_id = auth.uid();
    return query select true, cur_rev + 1, p_state;

  else
    -- konflik: kembalikan versi server, klien merge lalu push ulang
    return query select false, s.rev, s.state
                 from public.user_state s where s.user_id = auth.uid();
  end if;
end $$;

revoke all on function public.push_state(bigint, jsonb) from public;
grant execute on function public.push_state(bigint, jsonb) to authenticated;

-- push_state tanpa lost update.
--
-- Versi 0002 membaca `rev` lalu meng-update di pernyataan terpisah. Dua push
-- bersamaan dengan baseRev yang sama (dua tab, dua perangkat) sama-sama lolos
-- cek, sama-sama mendapat ok=true dengan rev yang sama, dan yang kalah
-- menganggap datanya sudah di server padahal tertimpa.
--
-- Sekarang cek dan tulis terjadi dalam satu UPDATE bersyarat: Postgres
-- mengunci barisnya, jadi hanya satu push per revisi yang bisa berhasil.
-- Yang lain mendapat konflik dan menjalankan merge seperti biasa.

create or replace function public.push_state(p_base_rev bigint, p_state jsonb)
returns table (ok boolean, rev bigint, state jsonb)
language plpgsql
security invoker
set search_path = public
as $$
declare new_rev bigint;
begin
  -- Baris pertama. `on conflict do nothing` menangani dua insert bersamaan:
  -- yang kalah jatuh ke jalur update/konflik di bawah, bukan error PK.
  insert into public.user_state(user_id, rev, state)
  values (auth.uid(), 1, p_state)
  on conflict (user_id) do nothing
  returning user_state.rev into new_rev;
  if new_rev is not null then
    return query select true, new_rev, p_state;
    return;
  end if;

  -- baseRev null = paksa tulis ("adopsi salinan perangkat ini").
  update public.user_state s
     set rev = s.rev + 1, state = p_state, updated_at = now()
   where s.user_id = auth.uid()
     and (p_base_rev is null or s.rev = p_base_rev)
  returning s.rev into new_rev;
  if new_rev is not null then
    return query select true, new_rev, p_state;
    return;
  end if;

  -- konflik: kembalikan versi server, klien merge lalu push ulang
  return query select false, s.rev, s.state
               from public.user_state s where s.user_id = auth.uid();
end $$;

revoke all on function public.push_state(bigint, jsonb) from public, anon;
grant execute on function public.push_state(bigint, jsonb) to authenticated;
