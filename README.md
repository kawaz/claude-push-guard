# claude-push-guard

> English | [日本語](./README-ja.md)

Claude Code plugin: a `PreToolUse(Bash)` hook that blocks Claude from running
`git push` / `jj git push` directly, and steers it through the repo's task
runner (`just push`) so check / test / translation-pair / version-bump gates
actually fire.

> **This is a personal-workflow plugin for kawaz.** It pins the push
> entrypoint to `just push` and assumes the kawaz/* `personal-docs-structure`
> convention (justfile + `bump-semver vcs` subcommands). It is not a
> general-purpose plugin for everyone.

## Why

In kawaz/* repos the `push` recipe in `justfile` chains a list of gates
(`push: ensure-clean ci check-translations check-version-bumped`).
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
| `just push` | pass |
| `gh pr create` / `gh release create` and other non-push git/gh commands | pass |
| `git push` appearing inside a commit-message string or heredoc | pass (no false positive) |

On block, the hook writes to stderr (1) the recommended command (`just push`)
and (2) where to learn the `justfile` layout if a repo doesn't have one yet
(the `personal-docs-structure` skill, or the canonical kawaz/bump-semver
justfile).

## Why `just push`

kawaz/* standardizes on `justfile` + `bump-semver vcs` subcommands (the
canonical implementation lives in `kawaz/bump-semver`). `just push` fans out
to:

- `bump-semver vcs push` — jj / git auto-dispatch
- `lint / test / validate / ci` deps
- `check-translations` — `*-ja.md` ↔ `*.md` pair gate
- `check-version-bumped` — bump-forgotten detection on `bump-trigger-paths`
- `ensure-clean` — working-tree clean check

The `justfile` layout is documented in the `personal-docs-structure` skill and
the canonical kawaz/bump-semver justfile.

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
- The expected push entrypoint is `just push`. Other wrappers are simply
  not blocked; the hook isn't an allowlist

## Related

- kawaz/bump-semver — canonical justfile implementation
- kawaz/claude-cmux-msg — multi-file version-bump example for claude-plugin repos
- kawaz/claude-bash-safety — sibling plugin (backtick mis-execution detection)

## License

MIT. See [LICENSE](./LICENSE).
