-- ChurchFinder — Phase 3 step 2: real sign-up/sign-in.
--
-- Adds what profiles needs to carry the app's own two-stage email
-- verification (personal-email code, then church-affiliation code) now that
-- accounts are real Supabase Auth users instead of a localStorage blob, and
-- adds the Row Level Security policies that let a signed-in user manage
-- their OWN profile row. Safe to re-run (every statement is idempotent).
--
-- Run this in the Supabase SQL Editor after 01_schema.sql and the seed
-- chunks from Phase 2.

alter table public.profiles add column if not exists personal_verified boolean not null default false;
-- {value, expires, sentAt} — same shape as the app's other verification
-- codes (see index.html's VERIFY_TTL_MS). Cleared once used.
alter table public.profiles add column if not exists personal_code jsonb;
alter table public.profiles add column if not exists church_code jsonb;

-- A signed-up-but-not-yet-verified user needs to be able to create their own
-- profile row (checked against auth.uid(), which Supabase Auth sets once
-- signUp() returns a session), read it back, and update it as they move
-- through verification. No policy here lets anyone touch a row that isn't
-- their own — that's what "auth.uid() = id" enforces on every one of these.
drop policy if exists "users can insert own profile" on public.profiles;
create policy "users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "users can view own profile" on public.profiles;
create policy "users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);
