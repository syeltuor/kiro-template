---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# GitHub Standards

How repositories are set up and used. No CI/CD is assumed.

## Visibility

- **Private by default.** Make a repo public only deliberately, and only after a
  privacy check of its full history.
- Check visibility with the GitHub API, unauthenticated:

  ```bash
  curl -s -o /dev/null -w '%{http_code}\n' https://api.github.com/repos/<owner>/<repo>
  # 404 = private (or missing), 200 = public
  ```

  **Not** `git ls-remote`: it succeeds on a private repo when credentials are
  stored, and it returns nothing on an empty repo, so it proves neither.

## Branches and merging

- `main` is the default branch and always deployable.
- Work on short-lived feature branches (`feature/<topic>`, `fix/<topic>`). Never
  push straight to `main` unless the owner asks.
- Merge by pull request or a reviewed fast-forward. No force-pushes to shared
  branches.
- Tag releases (`v1.0.0`) when a version matters to someone pulling it.

## Commits

- Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
  Small and focused.
- Commit identity per command (`git -c user.name=... -c user.email=... commit`) or
  per repo (`git config --local`). **Never rewrite global git config.**
- Never let a work email land in a personal repo (or the reverse). Check
  `git log --format='%an <%ae>'` before the first push. Templates use
  placeholders (`{{GIT_AUTHOR_NAME}}`, `{{GIT_AUTHOR_EMAIL}}`), never a real address.

## What lives in git

- **Everything that defines the project**: infra templates, scripts, application
  code, `.kiro/steering`, templates, README, and the design / plan / review notes
  (`.agents/<project>/`). The repo root can be the whole workspace.
- **Ignored**: only machine-local, secret or identifying files (`.env`, `.venv/`,
  `node_modules/`, `build/`, generated deploy config, `.DS_Store`). Baseline:
  `templates/gitignore` (copy to `.gitignore`).

## Never in git

- No secrets or personal identifiers ever, including in markdown notes, test
  fixtures and commit messages: API keys, tokens, account numbers, meter/device
  IDs, addresses, postcodes, coordinates, AWS account IDs in notes.
- Neutral example values in tests and docs.
- A **fail-closed privacy check** (`templates/scripts/privacy-check.sh`) runs
  before every push. It reads the real identifiers from SSM at run time (never
  embeds them) and refuses to report clean if it can't fetch them all.
- If something slips into history, treat it as compromised: rotate it, then
  decide with the owner whether to rewrite history.

## Pushing

- Push over **HTTPS**. Don't assume `gh` or SSH keys exist.
- In scripts and agents use `GIT_TERMINAL_PROMPT=0` so a missing credential fails
  instead of hanging.
- New branches: `git push -u origin <branch>`.
