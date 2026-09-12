-- ChurchFinder — Phase 4 step 4: real, server-enforced events and posts.
--
-- Before this, every event and post lived in localStorage — anyone could
-- post as any church just by editing storage. This adds real RLS to the
-- events/posts tables from Phase 2 (both had RLS enabled with no policies
-- since then, i.e. deny-all): a pastor can only post for the church they
-- really claim (churches.claimed_by, from Phase 4 step 1), and an
-- attendee's recap can only reference a REAL event that has REALLY passed —
-- not just whatever their local clock claims.
--
-- Safe to re-run (every statement is idempotent).

drop policy if exists "events are publicly readable" on public.events;
create policy "events are publicly readable"
  on public.events for select
  using (true);

drop policy if exists "claimant can post events for their church" on public.events;
create policy "claimant can post events for their church"
  on public.events for insert
  with check (
    auth.uid() = created_by
    and exists (select 1 from public.churches c where c.id = church_id and c.claimed_by = auth.uid())
  );

drop policy if exists "posts are publicly readable" on public.posts;
create policy "posts are publicly readable"
  on public.posts for select
  using (true);

-- A pastor's promo/update post requires real ownership of the church, same
-- as events. An attendee's recap requires no ownership at all (anyone can
-- attend a church's event) but DOES require the event to be real and
-- actually in the past by the DATABASE's own clock, not the poster's local
-- one — the entire point of the "only recap a past event" rule in the
-- first place.
drop policy if exists "claimant or attendee can post, each within their own rules" on public.posts;
create policy "claimant or attendee can post, each within their own rules"
  on public.posts for insert
  with check (
    auth.uid() = author_id
    and (
      (kind in ('promo','update') and exists (
        select 1 from public.churches c where c.id = church_id and c.claimed_by = auth.uid()
      ))
      or
      (kind = 'recap' and exists (
        select 1 from public.events e where e.id = event_id and e.church_id = posts.church_id and e.starts_at < now()
      ))
    )
  );
