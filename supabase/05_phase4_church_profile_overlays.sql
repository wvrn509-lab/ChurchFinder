-- ChurchFinder — Phase 4 step 2: real, server-enforced church page editing.
--
-- Mirrors the app's existing "overlay" design exactly: the base `churches`
-- table (from Phase 2) stays a read-only mirror of the imported directory,
-- and a pastor's edits (banner, logo, accent, tagline, about, contact info,
-- CTA button, social links) live in a SEPARATE table keyed by church_id —
-- same relationship as cf.churchprofiles.v1 (the local overlay) has always
-- had to SEED_CHURCHES/LOCAL_CHURCHES.
--
-- The write side is what actually changes here: before this, EP-1's save
-- only wrote to localStorage, so nothing stopped a tampered client from
-- saving edits to a church it doesn't own — the client-side canEditChurch()
-- check was the only gate. Now the write goes through this table's RLS,
-- which checks the REAL claimed_by column on churches (set by Phase 4 step
-- 1's trigger, not anything the client asserts) — a save attempt from
-- someone whose account isn't the church's real claimant is rejected by
-- Postgres itself, not just hidden by the UI.
--
-- Safe to re-run (every statement is idempotent).

create table if not exists public.church_profile_overlays (
  church_id      uuid primary key references public.churches (id),
  -- Temporary, same caveat as churches.photo_data_uri from Phase 2: base64
  -- image data, not yet in real object storage. Moves to Supabase Storage
  -- in a later Phase 4 step.
  banner         text,
  logo           text,
  accent         text,
  tagline        text,
  about          text,
  service_times  text,
  phone          text,
  website        text,
  email          text,
  cta            jsonb,
  socials        jsonb,
  updated_by     uuid references public.profiles (id),
  updated_at     timestamptz not null default now()
);

alter table public.church_profile_overlays enable row level security;

-- Overlays are shown on every visitor's view of a church page, signed in or
-- not — same as the base churches data.
drop policy if exists "church overlays are publicly readable" on public.church_profile_overlays;
create policy "church overlays are publicly readable"
  on public.church_profile_overlays for select
  using (true);

-- Insert/update both check the REAL ownership column on churches
-- (claimed_by, set only by the church_claims trigger from Phase 4 step 1) —
-- never anything the client sends in the row itself, so there's no field to
-- forge that would grant edit rights to a church you don't hold.
drop policy if exists "claimant can insert own church overlay" on public.church_profile_overlays;
create policy "claimant can insert own church overlay"
  on public.church_profile_overlays for insert
  with check (
    exists (select 1 from public.churches c where c.id = church_id and c.claimed_by = auth.uid())
  );

drop policy if exists "claimant can update own church overlay" on public.church_profile_overlays;
create policy "claimant can update own church overlay"
  on public.church_profile_overlays for update
  using (
    exists (select 1 from public.churches c where c.id = church_id and c.claimed_by = auth.uid())
  )
  with check (
    exists (select 1 from public.churches c where c.id = church_id and c.claimed_by = auth.uid())
  );
