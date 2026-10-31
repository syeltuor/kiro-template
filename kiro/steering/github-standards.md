---
inclusion: auto
name: github-standards
description: Git and GitHub workflow - repo visibility (private or public), checking if a repo is public, creating a repo, branches, commits and commit identity, author email, conventional commit messages, push, pull request, merge to main, tags and releases, .gitignore, what to keep out of git, privacy check before push, rewriting history. Use for any git or GitHub task.
---
<!-- kiro-template v2.0.0 -->

# GitHub Standards

No CI/CD is assumed.

## Visibility

- **Private by default.** Public only deliberately, after a privacy check of the
  full history.
- Check visibility with the GitHub API, unauthenticated:

  ```bash
  curl -s -o /dev/null -w '%{http_code}\n' https://api.github.com/repos/<owner>/<repo>
  # 404 = private (or missing), 200 = public
  ```

  **Not** `git ls-remote`: it succeeds on a private repo with stored credentials
  and returns nothing on an empty repo.

## Branches and commits

- `main` is the default, always deployable. Short-lived `feature/<topic>` /
  `fix/<topic>` branches; never push straight to `main` unless the owner asks. No
  force-pushes to shared branches. Tag releases (`v1.0.0`) when someone pulls by
  version.
- Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Identity per command (`git -c user.name=... -c user.email=... commit`) or
  `git config --local`. **Never change global git config.**
- Never a work email in a personal repo (or the reverse): check
  `git log --format='%an <%ae>'` before the first push. Templates use
  `{{GIT_AUTHOR_NAME}}` / `{{GIT_AUTHOR_EMAIL}}`.

## What lives in git

- **Everything that defines the project**: infra, scripts, code, `.kiro/steering`,
  README, and design/plan/review notes (`.agents/<project>/`).
- **Ignored**: only machine-local, secret or identifying files (`.env`, `.venv/`,
  `node_modules/`, `build/`, generated deploy config, `.DS_Store`). Baseline:
  `templates/gitignore`.
- The privacy check (`templates/scripts/privacy-check.sh`) reads the real
  identifiers from SSM at run time (never embeds them) and fails closed if it
  can't fetch them all. Also scrub AWS account IDs from notes.
- Something slipped into history: rotate it, then decide with the owner whether
  to rewrite history.

## Pushing

- **HTTPS**; don't assume `gh` or SSH keys exist.
- Scripts and agents set `GIT_TERMINAL_PROMPT=0` so a missing credential fails
  instead of hanging.
