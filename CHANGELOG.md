# Changelog

## 0.1.1 (2026-05-14)

- fix: `${CLAUDE_PLUGIN_ROOT}` 依存を撤廃し、`HINT_FILE` を `$0` 起点で解決
  (Claude Code がエラーヘッダで未展開のリテラルを表示する挙動の回避)
- refactor: `checkVersionBumped` を `bump-semver compare gt FILE vcs:origin/main`
  2 行に簡素化し、`push` deps に組み込み有効化

## 0.1.0 (2026-05-14)

初版。

- `PreToolUse(Bash)` フックで `git push` / `jj git push` を直接実行させずブロック
- 推奨は `pkf run push` (Taskfile.pkl)、justfile リポは `just push` でも可
- ブロック時の stderr で同梱 `hooks/push-migration-hint.md` を絶対パス表示
- コミットメッセージ・heredoc 内の文字列リテラルにある "git push" は誤検知しない
  (`(^|&&|;|\|\|?)\s*...` で行頭またはコマンドセパレータ直後のみ)
