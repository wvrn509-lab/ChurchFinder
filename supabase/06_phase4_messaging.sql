-- ChurchFinder — Phase 4 step 3: real, server-enforced private messaging.
--
-- Before this, every conversation lived in one flat THREADS array in
-- localStorage — anyone could read anyone else's messages just by editing
-- storage, and a conversation was invisible on any device other than the
-- one it started on. This moves thread creation and message send/receive
-- onto the threads/messages tables from Phase 2, with RLS restricting each
-- thread to its two real participants.
--
-- Messaging already requires sign-in in the app (see myThreadFor()'s dev
-- note), so this is fully compatible with policies keyed to auth.uid() —
-- no anonymous-visitor case to design around.
--
-- Safe to re-run (every statement is idempotent).

alter table public.threads  enable row level security;
alter table public.messages enable row level security;

drop policy if exists "participants can view their threads" on public.threads;
create policy "participants can view their threads"
  on public.threads for select
  using (auth.uid() = attendee_id or auth.uid() = pastor_id);

-- An attendee creates a thread for themselves, but pastor_id can't be
-- whatever the client sends — it must match the church's REAL current
-- claimant (churches.claimed_by, from Phase 4 step 1), so a message always
-- actually reaches the church's real pastor and never an arbitrary third
-- party the client names.
drop policy if exists "attendee can start a thread with the real pastor" on public.threads;
create policy "attendee can start a thread with the real pastor"
  on public.threads for insert
  with check (
    auth.uid() = attendee_id
    and pastor_id = (select claimed_by from public.churches where id = church_id)
  );

drop policy if exists "participants can view their messages" on public.messages;
create policy "participants can view their messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.threads t
      where t.id = thread_id and (t.attendee_id = auth.uid() or t.pastor_id = auth.uid())
    )
  );

-- Only a real participant of the thread can post into it, and only as
-- themselves (sender_id can't be forged to impersonate the other party).
drop policy if exists "participants can send messages" on public.messages;
create policy "participants can send messages"
  on public.messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.threads t
      where t.id = thread_id and (t.attendee_id = auth.uid() or t.pastor_id = auth.uid())
    )
  );
