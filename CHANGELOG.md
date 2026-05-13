# Changelog

## 0.1.0 (2026-05-14)

初版。

- `PreToolUse(Bash)` フックで `git push` / `jj git push` を直接実行させずブロック
- 推奨は `pkf run push` (Taskfile.pkl)、justfile リポは `just push` でも可
- ブロック時の stderr で同梱 `hooks/push-migration-hint.md` を絶対パス表示
- コミットメッセージ・heredoc 内の文字列リテラルにある "git push" は誤検知しない
  (`(^|&&|;|\|\|?)\s*...` で行頭またはコマンドセパレータ直後のみ)
