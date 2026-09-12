# Supabase migration files (Phase 2 of the blueprint)

These files stand up the database schema and seed the church directory. They
do **not** change how the live app behaves — index.html doesn't talk to
Supabase yet. That's Phase 3 (real auth) and Phase 4 (move the data), which
come after these are approved and run.

## How to run these

Both files run in the Supabase dashboard, using your own login — no API key
ever needs to leave Supabase for this step.

1. Open your project at https://supabase.com/dashboard/project/mrvqhmtbvcnciihiopbn
2. Go to **SQL Editor** (left sidebar) → **New query**
3. Open `01_schema.sql`, paste its full contents into the editor, click **Run**.
   - Creates 7 tables (`churches`, `profiles`, `church_claims`, `threads`,
     `messages`, `events`, `posts`), enables Row Level Security on all of
     them, adds a public read-only policy on `churches`, and creates a
     `church-media` storage bucket for Phase 4.
   - Every table except `churches` has RLS enabled with *no* policies yet —
     that means the app's public anon key cannot read or write any of them
     until Phase 3 adds real policies keyed to a signed-in user. This is
     intentional: nothing is exposed prematurely.
4. New query again. Open `02_seed_churches.sql`, paste it in, click **Run**.
   - Inserts all 3,150 churches (4 curated + 3,146 embedded) as rows with
     `legacy_id` values like `FC-1` and `LC-2967`, matching the ids already
     used throughout the live app and its tests.
   - It's ~1 MB of SQL. If the editor is slow to paste that much text, the
     file is just 13 independent `INSERT ... ON CONFLICT DO NOTHING`
     statements back to back — you can run it in a few chunks instead of all
     at once, in any order, and it's safe to re-run entirely if something
     fails partway.
5. To confirm it worked, run this in a new query:
   ```sql
   select count(*) as total, count(*) filter (where featured) as featured
   from public.churches;
   ```
   Expect `total = 3150`, `featured = 4`.

## Known gap: FC-1..FC-4 have no lat/lon yet

The 4 curated churches (`SEED_CHURCHES` in index.html) have never stored
coordinates — the live app geocodes their street address on every page load
instead. This migration carries that gap forward rather than guessing: their
`lat`/`lon` columns are `NULL` for now. Phase 4 (when the app talks to this
database directly) is the natural place to geocode them once and write the
result back, since the sandbox this was built in can't reach geocoding
services to do it here.

## What's next

Once you've run both files and confirmed the row count, that's Phase 2 done.
Phase 3 (real authentication — replacing the browser-side password/session
system with Supabase Auth) is the next phase in the blueprint, and it's the
one that actually starts changing index.html. I'll wait for you to say go
before starting it, same as this phase.
