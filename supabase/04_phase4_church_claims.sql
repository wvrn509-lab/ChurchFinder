-- ChurchFinder — Phase 4 step 1: real, server-enforced church claiming.
--
-- Before this, "who owns this church's edit rights" lived only in each
-- account's local churchId/churchVerified fields — trivially editable via
-- devtools, and "only one pastor per church" was checked by scanning the
-- local account list, which enforces nothing since the write itself was
-- never blocked. This makes the CLAIM EVENT itself real: a verified claim
-- is a database row, and the partial unique index from Phase 2
-- (church_claims_one_verified_per_church) means a second pastor who also
-- ends up with a valid code for the same church gets a real constraint
-- violation, not a silently-overwritten local list entry.
--
-- What's still client-enforced, and stays that way for now: the personal-
-- email and church-affiliation CODE CHECKS themselves. There's no server to
-- validate "did this browser really receive the emailed code" without an
-- edge function (Phase 8 territory) — same limitation the Phase 3 change
-- log already called out for personal-email verification. What moves to
-- the database here is the one thing that doesn't need that: once a claim
-- is asserted, nobody else can also assert it for the same church.
--
-- Safe to re-run (every statement is idempotent).

drop policy if exists "users can insert own church claim" on public.church_claims;
create policy "users can insert own church claim"
  on public.church_claims for insert
  with check (auth.uid() = profile_id);

drop policy if exists "users can view own church claims" on public.church_claims;
create policy "users can view own church claims"
  on public.church_claims for select
  using (auth.uid() = profile_id);

-- Keeps churches.claimed_by in sync with church_claims automatically, so
-- the client never asserts "set claimed_by to me" directly against
-- churches (which would need a much looser churches UPDATE policy than we
-- want). SECURITY DEFINER: runs as the function owner, not the calling
-- user, so it can write to churches even though the caller's own role
-- can't update that column directly.
create or replace function public.sync_church_claimed_by()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.status = 'verified' then
    update public.churches set claimed_by = NEW.profile_id where id = NEW.church_id;
  end if;
  return NEW;
end;
$$;

drop trigger if exists church_claims_sync_claimed_by on public.church_claims;
create trigger church_claims_sync_claimed_by
  after insert or update on public.church_claims
  for each row execute function public.sync_church_claimed_by();

-- Lets a pastor edit the church they've verified-claimed, once EP-1's save
-- flow moves to talking to this table directly (a later step) — added now
-- since it belongs with the ownership model, not because anything calls it
-- yet. Nothing in index.html uses this policy as of this migration.
drop policy if exists "claimant can update their church" on public.churches;
create policy "claimant can update their church"
  on public.churches for update
  using (claimed_by = auth.uid())
  with check (claimed_by = auth.uid());
