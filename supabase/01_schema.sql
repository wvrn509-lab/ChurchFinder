-- ChurchFinder — Phase 2 schema (Database and schema, per the migration blueprint)
--
-- This creates the tables that will eventually replace the seven localStorage
-- keys the app uses today. Nothing in index.html reads from these tables yet —
-- that's Phase 3 (auth) and Phase 4 (move the data). Running this script is
-- safe to do right now and changes nothing about how the live site behaves.
--
-- Run this whole file in the Supabase SQL Editor (Project -> SQL Editor -> New
-- query), then run seed_churches.sql in a second query.

-- ============================================================================
-- churches — replaces the SEED_CHURCHES (4 rows) + CHURCH_DATA.churches
-- (3,146 rows) arrays embedded in index.html.
-- ============================================================================
create table if not exists public.churches (
  id             uuid primary key default gen_random_uuid(),
  -- The app's existing id (FC-1..FC-4, LC-0..LC-3145). Kept forever per the
  -- blueprint so existing links, tests and #church-<id> hashes keep working
  -- through every later phase. Never reassign or reorder these.
  legacy_id      text unique not null,
  name           text not null,
  denom          text,
  denom_group    text,
  lat            double precision,
  lon            double precision,
  address        text,
  phone          text,
  website        text,
  email          text,
  hours          text,
  service_times  text,
  description    text,
  wheelchair     text,
  wikipedia      text,
  -- The 4 hand-researched churches (FC-1..FC-4) get featured placement
  -- ("Vigil" treatment) — mirrors p.featured in the client today.
  featured       boolean not null default false,
  -- Demo-only field carried over from SEED_CHURCHES; not a real claim.
  pastor_name    text,
  -- Temporary: base64 photo data, same shape as today's overlay. Moves to
  -- Supabase Storage in Phase 4 — this column exists now so Phase 3/4 don't
  -- need another schema change, but nothing should keep writing base64 here
  -- once storage is wired up.
  photo_data_uri text,
  -- Set once a pastor's claim is verified (Phase 3). NULL = unclaimed.
  claimed_by     uuid,
  created_at     timestamptz not null default now()
);
create index if not exists churches_denom_group_idx on public.churches (denom_group);
create index if not exists churches_lat_lon_idx on public.churches (lat, lon);

-- ============================================================================
-- profiles — one row per auth.users row (created in Phase 3). Replaces
-- cf.accounts.v2's non-secret fields; passwords/sessions become Supabase Auth's
-- job entirely, so there's no password/hash column here.
-- ============================================================================
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  email            text not null,
  role             text not null default 'attendee' check (role in ('attendee','pastor','admin')),
  display_name     text,
  photo_url        text,
  bio              text,
  church_id        uuid references public.churches (id),
  church_verified  boolean not null default false,
  created_at       timestamptz not null default now()
);

-- ============================================================================
-- church_claims — audit trail of claim attempts. churches.claimed_by holds the
-- *current* verified claimant; this table keeps history (including revoked
-- and pending ones), which admin tooling (AD-2) will want later.
-- ============================================================================
create table if not exists public.church_claims (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references public.churches (id),
  profile_id  uuid not null references public.profiles (id),
  status      text not null default 'pending' check (status in ('pending','verified','revoked')),
  created_at  timestamptz not null default now()
);
-- Only one verified claim per church at a time.
create unique index if not exists church_claims_one_verified_per_church
  on public.church_claims (church_id) where (status = 'verified');

alter table public.churches
  add constraint churches_claimed_by_fkey foreign key (claimed_by)
  references public.profiles (id) on delete set null;

-- ============================================================================
-- threads / messages — replaces cf.threads.v2. One thread per (church, attendee)
-- pair, matching how PI-1/CV-1 already group conversations.
-- ============================================================================
create table if not exists public.threads (
  id           uuid primary key default gen_random_uuid(),
  church_id    uuid not null references public.churches (id),
  attendee_id  uuid not null references public.profiles (id),
  pastor_id    uuid references public.profiles (id),
  created_at   timestamptz not null default now(),
  unique (church_id, attendee_id)
);

create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  thread_id   uuid not null references public.threads (id) on delete cascade,
  sender_id   uuid not null references public.profiles (id),
  body        text not null,
  created_at  timestamptz not null default now(),
  read_at     timestamptz
);
create index if not exists messages_thread_idx on public.messages (thread_id, created_at);

-- ============================================================================
-- events / posts — replaces cf.events.v1 and cf.posts.v1. A post can
-- optionally reference the event it's a recap of (attendee recaps only allowed
-- after the event's date/time — enforced in app logic, same as today).
-- ============================================================================
create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  church_id    uuid not null references public.churches (id),
  title        text not null,
  starts_at    timestamptz,
  location     text,
  description  text,
  created_by   uuid references public.profiles (id),
  created_at   timestamptz not null default now()
);

create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references public.churches (id),
  event_id    uuid references public.events (id),
  author_id   uuid not null references public.profiles (id),
  kind        text not null default 'update' check (kind in ('promo','update','recap')),
  body        text not null,
  created_at  timestamptz not null default now()
);
create index if not exists posts_church_idx on public.posts (church_id, created_at desc);

-- ============================================================================
-- Row Level Security — turned ON everywhere now, even though Phase 3 (real
-- auth) hasn't landed yet. `churches` gets a public read policy since that
-- data is already public in the live app. Every other table gets RLS enabled
-- with NO policies, which means "deny all" by default (the anon key can't
-- read or write profiles/threads/messages/events/posts/claims at all) — safe
-- until Phase 3 adds the real policies keyed to auth.uid(). This is
-- deliberate: better to expose nothing than to guess at policies before
-- there's a real signed-in user to test them against.
-- ============================================================================
alter table public.churches      enable row level security;
alter table public.profiles      enable row level security;
alter table public.church_claims enable row level security;
alter table public.threads       enable row level security;
alter table public.messages      enable row level security;
alter table public.events        enable row level security;
alter table public.posts         enable row level security;

create policy "churches are publicly readable"
  on public.churches for select
  using (true);

-- No insert/update/delete policy on churches for anon/authenticated — edits
-- to church profiles are added in Phase 3/4 as a policy scoped to
-- claimed_by = auth.uid(), mirroring the client's canEditChurch() check.

-- ============================================================================
-- Storage bucket for church banners/logos/avatars — created now so Phase 4
-- has somewhere to point uploads at, but nothing uploads here yet.
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('church-media', 'church-media', true)
on conflict (id) do nothing;
