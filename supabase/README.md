# Supabase migration files (Phase 2 of the blueprint)

These files stand up the database schema and seed the church directory. They
do **not** change how the live app behaves — index.html doesn't talk to
Supabase yet. That's Phase 3 (real auth) and Phase 4 (move the data), which
come after these are approved and run.

## How to run these

Both run in the Supabase dashboard, using your own login — no API key ever
needs to leave Supabase for this step.

1. Open your project's SQL Editor:
   `https://supabase.com/dashboard/project/mrvqhmtbvcnciihiopbn/sql/new`

2. **Schema.** Open `01_schema.sql`, paste its full contents in, click **Run**.
   - Creates 7 tables (`churches`, `profiles`, `church_claims`, `threads`,
     `messages`, `events`, `posts`), enables Row Level Security on all of
     them, adds a public read-only policy on `churches` (already public data
     in the live app), and creates a `church-media` storage bucket for
     Phase 4.
   - Every table except `churches` has RLS enabled with *no* policies —
     that means the app's public anon key can't read or write any of them
     until Phase 3 adds real policies keyed to a signed-in user. Intentional:
     nothing is exposed prematurely.

3. **Seed data — run these 7 files from `seed_chunks/`, in order, each as its
   own query.** The Supabase SQL Editor rejects very large pasted queries
   ("Query is too large to be run via the SQL Editor") — that's what happened
   when this was one ~1MB file. Splitting it into ~100KB chunks (all 3,150
   churches, ~500 per chunk) works around that limit cleanly:
   - `seed_chunks/02_seed_churches_01.sql` through `_07.sql`
   - For each: **New query** → paste the one file → **Run** → move to the next.
   - Every chunk ends in `ON CONFLICT (legacy_id) DO NOTHING`, so it's safe to
     re-run any chunk (or all of them) if one fails partway — nothing gets
     duplicated.

4. Confirm it worked:
   ```sql
   select count(*) as total, count(*) filter (where featured) as featured
   from public.churches;
   ```
   Expect `total = 3150`, `featured = 4`.

## Two known gaps, both deferred to Phase 4 on purpose

- **FC-1..FC-4 have no lat/lon yet.** The 4 curated churches
  (`SEED_CHURCHES` in index.html) have never stored coordinates — the live
  app geocodes their street address on every page load instead. This
  migration carries that gap forward rather than guessing: their `lat`/`lon`
  columns are `NULL` for now. Phase 4 (when the app talks to this database
  directly) is the natural place to geocode them once and write the result
  back — this sandbox can't reach geocoding services to do it here.

- **FC-1..FC-4 have no photo yet either.** Those 4 rows do have real photos
  in `index.html` (base64, ~100-160KB each) — they were deliberately left
  out of the seed rather than embedded as SQL text literals, because a
  single row with one of those photos is *itself* close to or over the size
  that gets a query rejected, and Phase 4 replaces base64-in-a-column with
  real Supabase Storage uploads anyway. Uploading them once, properly, as
  part of Phase 4 avoids doing this work twice. Nothing is lost — the photos
  are still sitting in index.html's `SEED_CHURCHES` array untouched.

## What's next

Once you've run the schema and all 7 seed chunks and confirmed the row
count, that's Phase 2 done. Phase 3 (real authentication — replacing the
browser-side password/session system with Supabase Auth) is next, and it's
the phase that actually starts changing index.html. I'll wait for you to say
go before starting it, same as this phase.
