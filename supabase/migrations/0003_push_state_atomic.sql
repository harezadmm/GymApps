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
