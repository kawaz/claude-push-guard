# Changelog

## 0.3.0 (2026-06-10)

- chore: 同梱の `hooks/push-migration-hint.md` を撤去。guard message は
  `just push` への誘導と `personal-docs-structure` skill / canonical の
  kawaz/bump-semver justfile への参照のみに簡素化 (移行ガイドの二重メンテを解消)
- docs: README / README-ja に「kawaz 個人ワークフロー専用プラグイン」である旨を明記
- chore: justfile を docs-structure 準拠に是正
  - `push-without-bump` recipe を削除 (bump-trigger に diff が無ければ version gate は
    自動 skip されるので不要。invariant のバイパス口を塞ぐ)
  - just 変数 (`version-files` / `bump-trigger-paths`) を撤廃し positional 引数渡しに
    (`set positional-arguments` 追加、`set lazy` 撤去)
  - bump-trigger を `hooks/` のみに絞る (test 専用変更で version bump を要求しない =
    canonical kawaz/bump-semver と同方針)
  - `lint-version-sync` と `check-versions` の重複を 1 本化
- tests: `just push-without-bump` の pass case を削除
- chore: marketplace.json の不要な `metadata.license` を撤去 (Claude Code が無視する
  未知フィールドで `claude plugin validate` が warning を出していた)

## 0.2.0 (2026-06-05)

- chore!: task runner を `Taskfile.pkl` (pkfire / pkf-tasks) から `justfile` に
  戻す。kawaz/* canonical (`personal-docs-structure` skill 準拠) が justfile
  単独運用へ集約されたのに追従
- guard message と `push-migration-hint.md` から `pkf run push` の言及を撤去、
  推奨は `just push` の 1 経路に整理
- README / README-ja も同方針で書き換え
- tests: pass case を `just push` / `just push-without-bump` に更新

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
