-- ChurchFinder — Phase 5 step 2: let a device discover every REAL
-- conversation an account is actually part of, not just ones it already
-- knows about locally.
--
-- Phase 4 step 3 (06_phase4_messaging.sql) covers reading/writing threads
-- and messages you're already a participant of, but nothing lets a
-- signed-in user LIST every threads row they're a participant in and then
-- learn the other side's name. profiles' own RLS ("users can view own
-- profile", 03_phase3_auth.sql) is correctly locked to auth.uid() = id —
-- which also correctly refuses to hand a conversation partner's
-- verification codes (personal_code/church_code, still columns on that
-- same row) to anyone else. A blanket "participants can view each other's
-- profile" policy would leak those columns along with the name.
--
-- This function exists specifically to expose ONLY what CV-1 actually
-- shows for the other participant — a name and a photo — and only to a
-- genuine, real participant of that specific thread. SECURITY DEFINER lets
-- it read the row profiles' own RLS would otherwise block, but the
-- function's own body is the only thing deciding what's allowed to escape:
-- return early with nothing for anyone who isn't really pastor_id or
-- attendee_id on that thread.
--
-- Safe to re-run (create or replace).

create or replace function public.thread_partner_info(p_thread_id uuid)
returns table(display_name text, photo_url text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_thread public.threads%rowtype;
  v_partner_id uuid;
begin
  select * into v_thread from public.threads where id = p_thread_id;
  if not found then
    return;
  end if;

  if auth.uid() = v_thread.pastor_id then
    v_partner_id := v_thread.attendee_id;
  elsif auth.uid() = v_thread.attendee_id then
    v_partner_id := v_thread.pastor_id;
  else
    -- Not a real participant of this thread — same "no error, just no
    -- data" shape every other RLS-style rejection already reads as in
    -- this app; nothing about that is new here.
    return;
  end if;

  return query
    select p.display_name, p.photo_url
    from public.profiles p
    where p.id = v_partner_id;
end;
$$;

grant execute on function public.thread_partner_info(uuid) to authenticated;
