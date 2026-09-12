# vendor/

Third-party client libraries kept in the repo rather than loaded from a CDN
at runtime.

## supabase-js.v2.umd.js

The official `@supabase/supabase-js` v2 client, UMD build, unmodified —
downloaded directly from jsDelivr's published package
(`https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js`),
not hand-edited in any way.

**Why vendored instead of a `<script src="https://cdn...">` tag** (the pattern
Leaflet and EmailJS still use in `index.html`): this sandbox's network proxy
resets browser-originated HTTPS connections to jsDelivr in a way that doesn't
affect `curl`/Node — a proxy quirk, not anything about jsDelivr or Chromium
individually. Vendoring the file sidesteps it entirely, and has a real
benefit beyond this sandbox: the login/data path no longer depends on a
third party's CDN being up.

## Updating the version

1. Download the new version's UMD build:
   ```
   curl -sL https://cdn.jsdelivr.net/npm/@supabase/supabase-js@<version>/dist/umd/supabase.js -o vendor/supabase-js.v2.umd.js
   ```
2. Update the filename/reference in `index.html` if the major version changes.
3. Run the full test suite before committing — this file changes what every
   Supabase-backed screen in the app runs on.
