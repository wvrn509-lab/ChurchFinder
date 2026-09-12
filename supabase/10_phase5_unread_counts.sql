-- ChurchFinder — Phase 5 step 3: unread counts become real server state.
--
-- Before this, "N new" badges on PI-1/AC-1 were per-browser flags
-- (THREADS[i].unreadPastor/unreadVisitor), bumped locally by whichever tab
-- sent the message and picked up by any OTHER tab sharing that same
-- browser's localStorage. That already worked for the app's own supported
-- "two tabs, one browser" testing pattern, but never crossed devices — a
-- pastor's SECOND phone had no way to know 3 messages were waiting, since
-- nothing about that count lived anywhere but the sender's own browser.
--
-- messages.read_at already exists as a column (01_schema.sql) and was
-- simply never written to or read from. This adds the one thing missing:
-- permission for a real participant to mark a message they received (not
-- one they sent) as read — and ONLY that column, not the message's
-- content or sender. Reads are already covered by "participants can view
-- their messages" (06_phase4_messaging.sql).
--
-- Column-level GRANT is used here (a first in this project's migrations)
-- specifically because row-level RLS alone can't stop a participant from
-- rewriting a message's `body` or `sender_id` on the same UPDATE that sets
-- read_at — Supabase's default bootstrap grants broad table privileges to
-- authenticated/anon and relies on RLS for row-level restriction, but nothing
-- here should ever let a participant tamper with the conversation record
-- itself, only acknowledge having read it.
--
-- Safe to re-run (every statement is idempotent).

revoke update on public.messages from authenticated;
grant update (read_at) on public.messages to authenticated;

drop policy if exists "participants can mark messages read" on public.messages;
create policy "participants can mark messages read"
  on public.messages for update
  using (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
      and (t.pastor_id = auth.uid() or t.attendee_id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
      and (t.pastor_id = auth.uid() or t.attendee_id = auth.uid())
    )
  );
