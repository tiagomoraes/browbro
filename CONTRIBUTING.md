# Contributing to browbro

Thanks for taking the time to contribute! This document explains the branching model,
naming conventions, and release process used in this repo.

## Branching model (Gitflow-lite)

This repo uses a lightweight version of [Gitflow](https://nvie.com/posts/a-successful-git-branching-model/)
with two long-lived branches:

| Branch    | Purpose                                              | Protected |
|-----------|-------------------------------------------------------|-----------|
| `main`    | The released state: tagged DMG releases, plus the live website. | Yes |
| `develop` | Integration branch for the next release. **Default branch** — PRs target this. | Yes |

All day-to-day work (features, fixes, chores, docs, etc.) branches off `develop` and is merged
back into `develop` via pull request. `main` moves forward through release and hotfix PRs, and
through site-only publish PRs (see [Publishing the website](#publishing-the-website)).

## Branch naming

Prefix your branch with the type of change, followed by a short, kebab-case description:

```
<type>/<short-description>
```

| Prefix       | Use for                                                        |
|--------------|-----------------------------------------------------------------|
| `feat/`      | A new feature                                                  |
| `fix/`       | A bug fix                                                       |
| `chore/`     | Maintenance that doesn't change app behavior (tooling, deps)   |
| `docs/`      | Documentation only                                              |
| `refactor/`  | Code change that neither fixes a bug nor adds a feature         |
| `test/`      | Adding or correcting tests                                      |
| `perf/`      | Performance improvements                                        |
| `ci/`        | CI configuration and scripts                                    |
| `build/`     | Build system or dependency changes                              |
| `style/`     | Formatting only, no code meaning change                         |
| `release/`   | Release stabilization branch, maintainers only (see below)      |
| `hotfix/`    | Urgent fix branched from `main`, maintainers only (see below)    |

Examples: `feat/menu-bar-browser-picker`, `fix/default-browser-detection`, `docs/readme-setup`.

A CI check enforces this on every PR.

## Commit messages & PR titles

Please follow [Conventional Commits](https://www.conventionalcommits.org/) for your PR title
(e.g. `feat: add menu bar browser picker`, `fix: correct default browser detection`). Topic PRs
are squash-merged, and the PR title becomes the commit message on `develop`, so a clean,
conventional title keeps history and changelogs useful. A CI check enforces this on every PR.

| PR | From → into | Merged with |
|----|-------------|-------------|
| Topic (`feat/`, `fix/`, `docs/`, …) | branch → `develop` | Squash |
| Release | `release/x.y.z` (or `develop`) → `main` | Merge commit |
| Back-merge | the same `release/x.y.z` → `develop` | Merge commit |
| Site publish | `chore/` or `docs/` branch → `main` | Squash |

## Contributing a change

1. Fork the repo (external contributors) or branch directly (maintainers).
2. Create a branch off `develop` using the naming convention above.
3. Make your change, with tests where it makes sense.
4. Open a pull request **against `develop`** (this is the default, so you shouldn't need to
   change anything). Fill in the PR template.
5. Address review feedback. Once checks pass, the PR is squash-merged.

## Release process

BrowBro ships through two channels, released independently:

- **DMG / Homebrew / Sparkle** — the `BrowBro` target, `0.1.x`, tagged `vX.Y.Z`.
- **Mac App Store** — the `BrowBroMAS` target, `1.x`, tagged `mas-vX.Y`.

### DMG channel

Releases are cut from `develop` onto `main` and tagged with [SemVer](https://semver.org/)
(`vMAJOR.MINOR.PATCH`).

1. Cut a `release/x.y.z` branch from `develop` and allow only fixes/docs/version-bump/appcast
   commits on it. (A release that needs no stabilization can PR `develop` into `main`
   directly — the branch-name check accepts it — and then has nothing to back-merge.)
2. Bump the shared `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` at the top of
   `project.yml` (`BrowBroMAS` overrides both with its own), and update `CHANGELOG.md`,
   moving the relevant `[Unreleased]` entries under a new `[x.y.z] - YYYY-MM-DD` heading
   (and adding its compare link at the bottom).
3. Build the signed, notarized DMG and commit its Sparkle appcast item, following
   [docs/NOTARIZING.md](docs/NOTARIZING.md) and [docs/UPDATES.md](docs/UPDATES.md).
4. Tag the release and publish a GitHub Release from the tag with `BrowBro.dmg` attached
   (`git tag vX.Y.Z && git push origin vX.Y.Z`), using "Generate release notes" (PRs are
   auto-labeled by type, so the notes come out categorized). Do this before merging into
   `main`: the appcast points at that asset, and the merge is what publishes the feed.
5. PR the branch into `main` and merge it with a **merge commit**, not a squash.
6. Open a second PR from the same `release/x.y.z` branch into `develop` (e.g.
   `chore: back-merge vX.Y.Z into develop`) and merge that with a merge commit too, so the
   version bump and any last-minute fixes aren't lost.
7. Bump the Homebrew cask ([docs/NOTARIZING.md](docs/NOTARIZING.md) → "Release it").

Publishing a `vX.Y.Z` GitHub Release does not touch the App Store.

### Mac App Store channel

The store ships from its own tag, not from a GitHub Release.

1. Set `BrowBroMAS`'s `MARKETING_VERSION` in `project.yml` to the version you're shipping,
   through a normal PR.
2. Tag the commit you want to ship and push the tag:
   `git tag mas-v1.1 && git push origin mas-v1.1`. The
   [`app-store.yml`](.github/workflows/app-store.yml) workflow archives and uploads the
   build, pushes the product page, and submits it for App Review.
3. To upload without submitting, add a suffix: `mas-v1.1-rc1` uploads the build and the
   product page and stops there.

The tag's version must equal `BrowBroMAS`'s `MARKETING_VERSION`, or the job fails before it
touches any secret. Store tags create no GitHub Release, so the website's "latest release"
download stays on the DMG. Manual runs and the details are in [docs/MAS.md](docs/MAS.md).

### Publishing the website

The live site deploys from `main` (the `deploy-pages` workflow runs on every push to `main`
that touches `site/`). Site and README changes land on `develop` like anything else; to put
one live before the next release, carry the same change to `main` in a site-only PR
(cherry-pick the `develop` commit onto a `chore/` or `docs/` branch, as
[#42](https://github.com/tiagomoraes/browbro/pull/42) did). No app
code goes to `main` this way.

### Hotfixes

For an urgent fix to a released version that can't wait for the next `develop` → `main` cycle:

1. Branch `hotfix/x.y.z` from `main`.
2. Fix, then PR **into `main`** (unlike day-to-day work, it doesn't target `develop`).
3. Tag and release as above.
4. Merge/cherry-pick the same fix back into `develop` so it isn't lost in the next release.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you're
expected to uphold it.
