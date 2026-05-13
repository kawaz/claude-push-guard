# claude-push-guard

> English | [日本語](./README-ja.md)

Claude Code plugin: a `PreToolUse(Bash)` hook that blocks Claude from running
`git push` / `jj git push` directly, and steers it through the repo's task
runner (`pkf run push` or `just push`) so check / test / translation-pair /
version-bump gates actually fire.

## Why

In kawaz/* repos the `push` task in `Taskfile.pkl` chains a list of gates
(`deps { ci; kawaz.docs.checkTranslations; checkVersionBumped; ... }`).
When Claude Code calls `git push` from the Bash tool it sidesteps every one
of those gates and ships a commit.

The previous mitigation was a per-repo `pre-push-check.sh` copied into
`.claude/hooks/`. That copy-paste mitigation drifted over time (slightly
different regex per repo, missing hooks in newer repos, etc.). This plugin
moves the guard to the user-global plugin layer so it can't be forgotten.

## Install

```bash
claude plugin marketplace add kawaz/claude-push-guard
claude plugin install push-guard@push-guard
```

This registers a `PreToolUse(Bash)` hook that runs `hooks/push-guard.sh`
before every Bash command.

## Behavior

| Pattern | Result |
|---|---|
| `git push ...` / `jj git push ...` at the start of a line or right after `&&` / `;` / `\|\|` / `\|` | **blocked** (exit 2) |
| `just push` / `pkf run push` / `pkf push` | pass |
| `gh pr create` / `gh release create` and other non-push git/gh commands | pass |
| `git push` appearing inside a commit-message string or heredoc | pass (no false positive) |

On block, the hook writes to stderr (1) the recommended commands
(`pkf run push` / `just push`) and (2) an absolute path to the bundled
migration guide (`${CLAUDE_PLUGIN_ROOT}/hooks/push-migration-hint.md`)
for repos that don't yet have `pkf` set up.

## Why `pkf run push`

kawaz/* standardizes on Taskfile.pkl + `kawaz/pkf-tasks`. `pkf run push`
fans out to:

- `kawaz.vcs.push` — jj / git auto-dispatch
- `lint / test / build / ci` deps
- `kawaz.docs.checkTranslations` — `*-ja.md` ↔ `*.md` pair gate
- `kawaz.semver.checkBumped` — bump-forgotten detection on `src/` changes
- `kawaz.migrate.{checkPkfTasks,checkPkfire}` — upgrade-drift detection

Repos still on `justfile` can keep using `just push` while migrating.
See `hooks/push-migration-hint.md` for migration patterns.

## Why mechanical block over "be careful"

A guideline that says "don't `git push` directly" gets buried in context.
Claude has been observed reasoning "I'll just push, the tests can run
separately." Blocking it in `PreToolUse` turns the rule from "be careful"
into "can't."

## Scope and limits

- Bash tool only (`matcher: Bash`)
- Detects `git push` / `jj git push` only at the **command position**
  (start of line or right after a shell separator). The regex is
  intentionally simple (`(^|&&|;|\|\|?)\s*...`) and does not parse the
  shell grammar — `eval`, `bash -c "..."`, and assembled-from-variables
  forms are not detected. This is a footgun guard, not a sandbox
- Permitted push entrypoints are `pkf run push` / `just push`. Other
  wrappers are simply not blocked; the hook isn't an allowlist

## Related

- kawaz/pkf-tasks — shared Taskfile.pkl modules
- kawaz/bump-semver — canonical Taskfile.pkl implementation
- kawaz/claude-bash-safety — sibling plugin (backtick mis-execution detection)

## License

MIT. See [LICENSE](./LICENSE).
