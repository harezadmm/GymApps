-- Kuota analisis AI recap yang atomik (v3.1).
--
-- Fungsi Vercel /api/recap-analyze memanggil consume_ai_quota() dengan token
-- pemakai sendiri sebelum menghubungi Gemini. Pengecekan dan penambahan
-- terjadi dalam satu UPDATE bersyarat: Postgres mengunci barisnya, jadi
-- permintaan paralel tidak bisa melewati batas (Runtime Cache Vercel tidak
-- punya operasi atomik — itu hanya cadangan selama migrasi ini belum ada).
--
-- Batasnya tertanam di fungsi, bukan parameter: memanggil RPC ini langsung
-- dengan token sendiri hanya bisa menghabiskan kuota sendiri, tidak bisa
-- melonggarkannya. Tidak ada fungsi "kembalikan kuota" — yang bisa dipanggil
-- pemakai untuk menyetel ulang hitungannya sendiri.
--
-- Mengubah batas = migrasi baru yang mengganti fungsi ini.

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day     date not null,
  used    integer not null default 0,
  primary key (user_id, day)
);

create table if not exists public.ai_usage_global (
  day  date primary key,
  used integer not null default 0
);

-- RLS tanpa policy: kedua tabel hanya tersentuh lewat fungsi di bawah.
alter table public.ai_usage enable row level security;
alter table public.ai_usage_global enable row level security;

-- Sisa kuota akun hari ini (≥ 0) setelah satu analisis dicatat,
-- -1 = batas akun tercapai, -2 = batas harian global tercapai.
create or replace function public.consume_ai_quota()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  per_user   constant integer := 20;
  global_cap constant integer := 200;
  uid  uuid := auth.uid();
  n    integer;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  insert into public.ai_usage (user_id, day, used)
  values (uid, current_date, 0)
  on conflict (user_id, day) do nothing;

  update public.ai_usage
     set used = used + 1
   where user_id = uid and day = current_date and used < per_user
  returning used into n;
  if n is null then
    return -1;
  end if;

  insert into public.ai_usage_global (day, used)
  values (current_date, 0)
  on conflict (day) do nothing;

  update public.ai_usage_global
     set used = used + 1
   where day = current_date and used < global_cap;
  if not found then
    -- Batas global: hitungan akun tadi dibatalkan, analisis tidak terjadi.
    update public.ai_usage set used = used - 1 where user_id = uid and day = current_date;
    return -2;
  end if;

  return per_user - n;
end $$;

revoke all on function public.consume_ai_quota() from public, anon;
grant execute on function public.consume_ai_quota() to authenticated;
