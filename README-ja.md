# claude-push-guard

> [English](./README.md) | 日本語

Claude Code プラグイン: `git push` / `jj git push` を Bash ツールから
直接実行させず、リポ定義のタスクランナー (`pkf run push` ないし `just push`)
経由でのみ push を許可する `PreToolUse(Bash)` フック。

## なぜ必要か

kawaz/* のリポは push 直前に check / test / 翻訳ペア検証 / version bump gate
など複数の門番を `Taskfile.pkl` の `push` task の `deps` に積んでいる。
Claude Code が Bash ツールで `git push` / `jj git push` を**直接打つ**と、
これらをまるごとスキップして commit を世に出してしまう。

各リポに `pre-push-check.sh` をコピペで配ってこの事故を防いできたが、
**配り忘れ・微妙な regex 差分・「リポ作成時に hook を入れ忘れた」**
といった漏れが構造的に発生していた。本プラグインはそれをユーザグローバルな
プラグインに一元化する。

## インストール

```bash
claude plugin marketplace add kawaz/claude-push-guard
claude plugin install push-guard@push-guard
```

`PreToolUse(Bash)` フックが登録され、Claude Code の Bash tool 実行ごとに
`hooks/push-guard.sh` を経由する。

## 検出と挙動

| パターン | 挙動 |
|---|---|
| `git push ...` / `jj git push ...` (行頭または `&&` / `;` / `\|\|` / `\|` の直後) | **block** (exit 2) |
| `just push` / `pkf run push` / `pkf push` | pass |
| `gh pr create` / `gh release create` 等 push を含まない git/gh コマンド | pass |
| コミットメッセージや heredoc 内の文字列リテラルに含まれる `git push` | pass (誤検知しない) |

ブロック時は stderr に **(1) 推奨コマンド** (`pkf run push` / `just push`)
と **(2) リポに pkf が未整備な場合の移行ガイドへの絶対パス**
(`${CLAUDE_PLUGIN_ROOT}/hooks/push-migration-hint.md`) を返す。

## 何故 `pkf run push` を推奨するか

kawaz/* では Taskfile.pkl + `kawaz/pkf-tasks` を canonical にしている。
`pkf run push` ひとつで:

- `kawaz.vcs.push` で jj / git の auto-dispatch
- `lint / test / build / ci` の deps を一括実行
- `kawaz.docs.checkTranslations` で `*-ja.md` ↔ `*.md` の translation pair gate
- `kawaz.semver.checkBumped` で src/ 変更時の version bump 忘れ検出
- `kawaz.migrate.checkPkfTasks` / `kawaz.migrate.checkPkfire` で
  pkf-tasks / pkfire の追従漏れ検出

が回る。justfile しか無いリポは当面 `just push` で良いが、Taskfile.pkl への
移行を推奨。詳細は同梱の `hooks/push-migration-hint.md` を参照。

## 「気をつける」では駄目な理由

`git push` をうっかり打たないようルールに書いても、ルールはコンテキスト
の隅に埋もれる。Claude が「テストは別途回せばいい」と判断して直叩きに
走るシナリオは何度も観測されている。`PreToolUse` で機械的にブロックする
ことで、属人的な「気をつける」を「踏めない」に変える。

## 制限とスコープ

- Bash tool 限定 (matcher: `Bash`)
- `git push` / `jj git push` の **コマンド位置** にあるものだけ検出。
  シェルの構文解析を真面目にやらない雑な regex (`(^|&&|;|\|\|?)\s*...`)
  なので、`eval` / `bash -c "..."` の中に隠した場合や、変数展開で組み立てた
  `$cmd_with_push` のようなケースは検出できない。Claude が意図的に回避する
  ような書き方を防ぐ用途ではない (そういう用途は別の仕組みが必要)
- 想定する push 受け口は `pkf run push` / `just push` のみ。他のラッパーは
  プラグイン側で許可リスト化していない (ホスト側は通すだけなので、勝手に
  独自 task 名を使うことは可能)

## 関連

- `~/.claude/rules/push-workflow.md` - push 後 CI watch ルール (個人ルール)
- `~/.claude/rules/docs-structure.md` - canonical Taskfile.pkl テンプレ章
- kawaz/pkf-tasks - 共通 task module
- kawaz/bump-semver - canonical 実装
- kawaz/claude-bash-safety - 姉妹プラグイン (backtick 誤実行検出)

## License

MIT. See [LICENSE](./LICENSE).
