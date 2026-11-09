# Maintainers' guide: merge process

Branches: work happens on feature branches, `develop` is the integration branch, `main` is released.
Both `develop` and `main` are protected by rulesets (stored in `.github/rulesets/`).

## Merge flow

### 1. Feature to `develop`

Open a PR from your branch into `develop` and **squash merge** it. This keeps `develop` to one commit per change.

### 2. `develop` to `main` (release)

Open a PR from `develop` into `main` and use **Create a merge commit** (not squash, not rebase). `main` keeps `develop`'s history, so the two branches stay in sync and there is no back-merge step.

That's it. Don't squash this PR: a squash creates a commit on `main` that `develop` doesn't have, and you'd have to merge `main` back into `develop` afterwards.

## If `develop` and `main` have drifted

Only needed after an accidental squash into `main`. Merge `main` back into `develop` with a standard merge commit:

- **Via a pull request.** `develop` allows **squash only** (`.github/rulesets/develop.json`), so this flattens the merge. To get a real merge commit, add `"merge"` to `allowed_merge_methods` for `develop` (in the file and in the repo's settings).
- **As an admin, no PR.** Admins can bypass the PR rule (`bypass_actors` has the admin role with mode `always`):

  ```
  git checkout develop
  git pull
  git merge main
  git push
  ```

  This skips the review and checks, so only use it for this sync, which adds no new code.

## Branch rules (summary)

| | `develop` | `main` |
|---|---|---|
| Pull request required | yes | yes |
| Approvals | 1, from a code owner | 1, from a code owner |
| Allowed merge methods | squash | merge, squash, rebase |
| Required Jenkins checks | `pr-head`, `pr-merge` | `branch`, `pr-head`, `pr-merge` |
| Force-push / delete | blocked | blocked |
| Admin bypass | yes | yes |

The rulesets in `.github/rulesets/` are the stored copies. Changing them there doesn't change GitHub; update the repo's rulesets in Settings as well.

## Releasing

Merging to `main` with a new `version` in `galaxy.yml` (and a matching `## <version>` section in `CHANGELOG.md`) makes Jenkins create the GitHub release and tag. After a release, install it in every repo that uses the collection:

```
ansible-galaxy collection install -r requirements.yml --force
```
