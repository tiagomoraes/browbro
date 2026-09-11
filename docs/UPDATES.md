# In-app updates (Sparkle)

BrowBro ships outside the App Store (DMG + Homebrew cask), so it updates itself
with [Sparkle](https://sparkle-project.org) — the standard framework for
non-App-Store macOS apps. Sparkle only updates an install whose bundle ID
matches the new build (`cloud.tiagomoraes.browbro`). The last `so.aca.browbro`
release is 0.1.7 — those copies need a fresh download. The Mac App Store binary (`BrowBroMAS`) does not
include Sparkle; those copies update through the store (guideline 2.4.5(vii)).
See [MAS.md](MAS.md). From **Settings → Updates** (or the menu-bar
**Check for Updates…** item) BrowBro checks a signed feed, and when a newer build
exists it downloads, verifies, and installs it in place, then relaunches. No
re-download, no drag-to-Applications.

## How trust works

Each update archive is signed with an **EdDSA (ed25519)** key. The matching
public key is embedded in the app (`SUPublicEDKey` in `Resources/Info.plist`);
Sparkle refuses any update whose signature doesn't verify against it. That check
is independent of Apple's — releases are also Developer ID signed and notarized
(see [NOTARIZING.md](NOTARIZING.md)), so an update has to satisfy both.

**The EdDSA key is what makes the signing identity replaceable.** Sparkle accepts
an update when *either* the EdDSA key matches *or* the Apple code-signing identity
matches, precisely so identities can rotate without stranding installed copies.
Keeping `SUPublicEDKey` stable is therefore more load-bearing than the certificate:
lose the certificate and you buy a new one; lose the EdDSA key and every install
stops trusting updates.

- **Feed:** `https://browbro.tiagomoraes.cloud/appcast.xml` (served by GitHub
  Pages from [`site/appcast.xml`](../site/appcast.xml)).
- **Public key:** `WYtqTgJc2C4c4UUZvfj/wa2qpCi11K584cjDcVf+gwU=`
- **Private key:** stored in the maintainer's **login keychain** (generated once
  with Sparkle's `generate_keys`). It is **never** committed. Losing it means a
  new key pair — and every already-installed copy stops trusting updates until
  users manually install a build carrying the new public key. **Back it up:**
  ```sh
  ./bin/generate_keys -x sparkle_private_key.txt   # then store it somewhere safe & delete the file
  ```
  (`generate_keys`/`sign_update` live under
  `build/SourcePackages/artifacts/sparkle/Sparkle/bin/` after
  `xcodebuild -resolvePackageDependencies`.)

## Cutting a release with an update

Sparkle decides "is this newer?" by comparing **`CFBundleVersion`**
(`CURRENT_PROJECT_VERSION` in `project.yml`). It **must strictly increase** on
every public release, or clients won't see the update.

1. Bump both `MARKETING_VERSION` (e.g. `0.1.5`) and `CURRENT_PROJECT_VERSION`
   (e.g. `5`) in `project.yml`, and move the `CHANGELOG.md` entries under a new
   heading. (Follow the normal release flow in [CONTRIBUTING.md](../CONTRIBUTING.md).)
2. Build the release DMG with `packaging/notarize/notarize-release.sh build/BrowBro.dmg`
   — signed, notarized and stapled (see [NOTARIZING.md](NOTARIZING.md)). Never ship
   `packaging/dmg/build-dmg.sh` output; that one is for local previews only.
3. Generate the appcast `<item>` and paste it at the top of the `<channel>` in
   `site/appcast.xml`:
   ```sh
   packaging/appcast/generate-item.sh build/BrowBro.dmg
   ```
   The script signs the DMG with the keychain private key and prints a ready
   `<item>` (version, download URL, size, EdDSA signature, release notes from
   `CHANGELOG.md`).
4. Create the GitHub release `vX.Y.Z` and upload the DMG as **`BrowBro.dmg`**
   (the exact name the appcast URL and the website expect).
5. Merge `site/appcast.xml` to `main` so GitHub Pages publishes the new feed.
6. Bump the Homebrew cask (see [NOTARIZING.md](NOTARIZING.md) → "Release it").

Existing installs then pick up the update on their next scheduled check (or when
the user hits **Check Now**).

> Sparkle updates only work for builds that already contain Sparkle, i.e. `0.1.4`
> and later. Users on `0.1.3` or earlier must install `0.1.4+` manually once;
> after that, updates are automatic.
