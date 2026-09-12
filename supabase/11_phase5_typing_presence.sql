-- ChurchFinder — Phase 5 step 4: typing presence across real devices.
--
-- CV-1's typing indicator has worked since before this migration started,
-- but only within ONE browser: markTyping()/clearTyping() write to a
-- localStorage key (cf.typing.v1), which a genuinely different device
-- never sees. This adds the smallest real table needed to carry the same
-- signal across devices — a heartbeat, not a chat message, and explicitly
-- NOT something that needs to survive a restart or be queried in bulk.
--
-- One row per (thread, user): "this person was typing as of this time."
-- Reading side treats a row older than the app's own TYPING_TTL_MS as
-- stopped — same TTL-based "a vanished tab can't clean up after itself"
-- reasoning the local mechanism already uses, just now over a real device
-- boundary instead of a closed tab.
--
-- Safe to re-run (every statement is idempotent).

create table if not exists public.typing_status (
  thread_id   uuid not null references public.threads (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  updated_at  timestamptz not null default now(),
  primary key (thread_id, user_id)
);
alter table public.typing_status enable row level security;

drop policy if exists "participants can view typing status for their threads" on public.typing_status;
create policy "participants can view typing status for their threads"
  on public.typing_status for select
  using (
    exists (
      select 1 from public.threads t
      where t.id = typing_status.thread_id
      and (t.pastor_id = auth.uid() or t.attendee_id = auth.uid())
    )
  );

drop policy if exists "participants can mark themselves typing" on public.typing_status;
create policy "participants can mark themselves typing"
  on public.typing_status for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.threads t
      where t.id = typing_status.thread_id
      and (t.pastor_id = auth.uid() or t.attendee_id = auth.uid())
    )
  );

drop policy if exists "participants can update their own typing status" on public.typing_status;
create policy "participants can update their own typing status"
  on public.typing_status for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "participants can clear their own typing status" on public.typing_status;
create policy "participants can clear their own typing status"
  on public.typing_status for delete
  using (auth.uid() = user_id);
