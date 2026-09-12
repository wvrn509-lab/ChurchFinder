# Native app wrapper (Phase 6 of the blueprint)

This wraps the existing `index.html` in a native iOS shell using Capacitor.
It does **not** change how the app behaves on the web — Netlify still
publishes `index.html` from the repo root exactly as before, untouched.
Everything here is additive packaging, not a rewrite.

## What exists so far

- `package.json` / `package-lock.json` — the Capacitor CLI and core packages,
  plus the three plugins Phase 6 needs: camera, geolocation, push
  notifications. `npm install` pulls these; nothing here needs a bundler for
  `index.html` itself.
- `capacitor.config.json` — `appId` is a **placeholder**
  (`com.churchfinder.app`). Change it before your first real build if you
  already have a bundle identifier in mind (once it's set in App Store
  Connect it becomes very hard to change) — it's a single line to edit.
- `ios/` — a real, generated Xcode project (`ios/App/App.xcodeproj`). Uses
  Swift Package Manager for the Capacitor plugins, not CocoaPods, so there's
  no `pod install` step. **This is checked into git** — unlike `node_modules`
  or `www`, this is a real project you'll open and may hand-edit in Xcode
  (icons, entitlements, signing), so it belongs in version control the same
  way the rest of the app does.
  - `Info.plist` already has the three permission strings the app will need
    once the camera/geolocation code lands (Step 2+ of this phase) —
    `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`,
    `NSLocationWhenInUseUsageDescription`. Missing one of these doesn't show
    an error dialog on a real device — it silently kills the app the instant
    that feature is touched, so they're in place now rather than added
    reactively after a crash report.
- `npm run build` — copies `index.html` and `vendor/` into `www/` (gitignored,
  regenerated every time). Not a real build step — no bundling, no
  transpilation, just what Capacitor's `webDir` needs to point at. The app's
  own code is completely unchanged by this.
- `npm run sync` — runs the copy above, then `npx cap sync` (copies the fresh
  web assets into `ios/App/App/public` and re-resolves the plugin list).

## What this step deliberately does NOT include yet

- **No camera/geolocation/push code in `index.html` yet.** The plugins are
  installed and permission strings exist, but nothing in the app calls them —
  the three `<input type="file">` pickers (banner/logo on EP-1, avatar on
  AC-1) and the text-based location search are exactly what they were before
  this file existed. That's the next step, once you've confirmed this
  scaffold actually opens and builds in Xcode.
- **No app icon or launch screen art.** The template's placeholder assets are
  still in `ios/App/App/Assets.xcassets` — real icons are a design asset, not
  something to fabricate here.
- **No push notification *sending*.** Registering a device for a token is
  Phase 6 work; actually delivering a push needs a server-side sender, which
  is Phase 8.
- **Android.** Nothing here touches Android — everything above is iOS-only
  for now, matching what you actually have (Xcode, no stated Android need).

## What to run on your Mac

This sandbox has no Xcode and no iOS Simulator, so everything above was
built and verified as far as a plain Linux machine can (`npm install`,
`npx cap add ios`, `npx cap sync` all ran clean, and the web assets landed
correctly in the native project) — but nobody has actually opened or built
this in Xcode yet. That part is yours:

```bash
git pull
npm install
npm run sync        # safe to re-run any time you change index.html
npx cap open ios    # opens the real Xcode project
```

In Xcode: pick a Simulator (or your own device, which works without a paid
Apple Developer account for a 7-day provisioning window), hit Run. If it
launches and you see the real ChurchFinder app, this step is done and Step 2
(wiring up the camera) can start.

## What I need from you before Step 2

Nothing blocking — Step 2 (camera) doesn't need a bundle ID decision or a
developer account, both of which can wait. Just confirm the app actually
opens in Xcode and runs in the Simulator, so we know the scaffold itself is
sound before building the real feature work on top of it.
