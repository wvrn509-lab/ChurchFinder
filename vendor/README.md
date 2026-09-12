# vendor/

Third-party client libraries kept in the repo rather than loaded from a CDN
at runtime.

## capacitor-core.v8.js / capacitor-camera.v8.js

`@capacitor/core`'s and `@capacitor/camera`'s browser bundles
(`dist/capacitor.js` and `dist/plugin.js` respectively), copied unmodified
from `node_modules` after `npm install`. **Load order matters**:
capacitor-core must load before capacitor-camera — the camera bundle
references a bare global (`capacitorExports`) that only the core bundle
defines, so swapping the order (or dropping either script tag) leaves
`Capacitor.Plugins.Camera` undefined and the app's "Camera not available."
error fires for everyone.

This project has no bundler, so unlike a normal Capacitor project (where
`import { Camera } from '@capacitor/camera'` pulls this in automatically),
these have to be plain `<script>` tags. The native iOS runtime injects its
own `window.Capacitor` (isNativePlatform(), etc.) automatically — that part
needs no script tag — but the JS side of an individual *plugin*
(`Capacitor.Plugins.Camera`) is never auto-injected by the native runtime;
it only exists once something loads and runs the plugin's own JS bundle,
which is what these two files are for.

### Updating the version
```
npm install @capacitor/core@<version> @capacitor/camera@<version>
cp node_modules/@capacitor/core/dist/capacitor.js vendor/capacitor-core.v8.js
cp node_modules/@capacitor/camera/dist/plugin.js vendor/capacitor-camera.v8.js
```
Rename both files (and the `<script src>` tags in `index.html`) if the major
version changes, matching the `v8` in the current filenames.

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
