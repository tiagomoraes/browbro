# Contributing to browbro

Thanks for taking the time to contribute! This document explains the branching model,
naming conventions, and release process used in this repo.

## Branching model (Gitflow-lite)

This repo uses a lightweight version of [Gitflow](https://nvie.com/posts/a-successful-git-branching-model/)
with two long-lived branches:

| Branch    | Purpose                                              | Protected |
|-----------|-------------------------------------------------------|-----------|
| `main`    | Always production-ready. Every commit is a tagged release. | Yes |
| `develop` | Integration branch for the next release. **Default branch** — PRs target this. | Yes |

All day-to-day work (features, fixes, chores, docs, etc.) branches off `develop` and is merged
back into `develop` via pull request. `main` only moves forward through release or hotfix PRs.

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
(e.g. `feat: add menu bar browser picker`, `fix: correct default browser detection`). PRs are
squash-merged, and the PR title becomes the commit message on `develop`/`main`, so a clean,
conventional title keeps history and changelogs useful. A CI check enforces this on every PR.

## Contributing a change

1. Fork the repo (external contributors) or branch directly (maintainers).
2. Create a branch off `develop` using the naming convention above.
3. Make your change, with tests where it makes sense.
4. Open a pull request **against `develop`** (this is the default, so you shouldn't need to
   change anything). Fill in the PR template.
5. Address review feedback. Once checks pass, the PR is squash-merged.

## Release process

Releases are cut from `develop` onto `main` and tagged with [SemVer](https://semver.org/)
(`vMAJOR.MINOR.PATCH`).

1. When `develop` is ready to ship, open a PR from `develop` into `main`.
   - For a larger release that needs stabilization time, cut a `release/x.y.z` branch from
     `develop` instead, allow only fixes/docs/version-bump commits on it, then PR that branch
     into `main` (and merge it back into `develop` afterwards so those last-minute fixes aren't
     lost).
2. Update `CHANGELOG.md`, moving the relevant `[Unreleased]` entries under a new
   `[x.y.z] - YYYY-MM-DD` heading.
3. Merge the PR into `main`.
4. Tag the merge commit: `git tag vX.Y.Z && git push origin vX.Y.Z`.
5. Publish a GitHub Release from the tag, using "Generate release notes" (PRs are auto-labeled
   by type, so the notes come out categorized).

### Hotfixes

For an urgent fix to a released version that can't wait for the next `develop` → `main` cycle:

1. Branch `hotfix/x.y.z` from `main`.
2. Fix, then PR **into `main`** (this is the one case where a PR doesn't target `develop`).
3. Tag and release as above.
4. Merge/cherry-pick the same fix back into `develop` so it isn't lost in the next release.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you're
expected to uphold it.
