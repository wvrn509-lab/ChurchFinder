-- ChurchFinder — Phase 4 step 5: real file storage for images.
--
-- Before this, every banner, logo, and profile photo was base64 TEXT
-- stuffed into a database column (and, before Phase 2, directly into
-- localStorage) — this is what the original storage-quota bug (fixed at
-- the very start of this migration) was about, and it never really goes
-- away as long as images are text in a column instead of files in real
-- storage. This adds the upload policies for the church-media bucket
-- Phase 2 already created (public: true, so reads need no policy at all —
-- Storage serves a public bucket's objects over a public URL regardless of
-- RLS). Only uploads need rules.
--
-- Path convention, enforced by these policies rather than just assumed by
-- the client:
--   churches/<church id>/banner-<timestamp>.jpg
--   churches/<church id>/logo-<timestamp>.jpg
--   avatars/<profile id>-<timestamp>.jpg
--
-- Safe to re-run (every statement is idempotent).

drop policy if exists "claimant can upload their church's media" on storage.objects;
create policy "claimant can upload their church's media"
  on storage.objects for insert
  with check (
    bucket_id = 'church-media'
    and (storage.foldername(name))[1] = 'churches'
    and exists (
      select 1 from public.churches c
      where c.id::text = (storage.foldername(name))[2]
      and c.claimed_by = auth.uid()
    )
  );

drop policy if exists "claimant can replace their church's media" on storage.objects;
create policy "claimant can replace their church's media"
  on storage.objects for update
  using (
    bucket_id = 'church-media'
    and (storage.foldername(name))[1] = 'churches'
    and exists (
      select 1 from public.churches c
      where c.id::text = (storage.foldername(name))[2]
      and c.claimed_by = auth.uid()
    )
  );

drop policy if exists "user can upload their own avatar" on storage.objects;
create policy "user can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'church-media'
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(name, '/', 2) like (auth.uid()::text || '-%')
  );

drop policy if exists "user can replace their own avatar" on storage.objects;
create policy "user can replace their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'church-media'
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(name, '/', 2) like (auth.uid()::text || '-%')
  );
