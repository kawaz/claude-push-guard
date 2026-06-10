# claude-push-guard

> [English](./README.md) | 日本語

Claude Code プラグイン: `git push` / `jj git push` を Bash ツールから
直接実行させず、リポ定義のタスクランナー (`just push`) 経由でのみ push を
許可する `PreToolUse(Bash)` フック。

> **これは kawaz 個人のワークフロー専用プラグインです。** push の受け口を
> `just push` に固定し、kawaz/* リポの `personal-docs-structure` 規約
> (justfile + `bump-semver vcs` サブコマンド) を前提にしています。
> 万人向けの汎用プラグインではありません。

## なぜ必要か

kawaz/* のリポは push 直前に check / test / 翻訳ペア検証 / version bump gate
など複数の門番を `justfile` の `push` recipe の deps に積んでいる。
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

## アップデート

```bash
claude plugin marketplace update push-guard
claude plugin update push-guard@push-guard
```

更新は cache 反映まで。実行中セッションに効かせるには `/reload-plugins`
（または restart）。`just push` した本人の環境では push recipe が
`on-success-release` を呼んで上記 2 コマンドを自動実行する（CI 無しリポなので push 直後に実行）。

## 検出と挙動

| パターン | 挙動 |
|---|---|
| `git push ...` / `jj git push ...` (行頭または `&&` / `;` / `\|\|` / `\|` の直後) | **block** (exit 2) |
| `just push` | pass |
| `gh pr create` / `gh release create` 等 push を含まない git/gh コマンド | pass |
| コミットメッセージや heredoc 内の文字列リテラルに含まれる `git push` | pass (誤検知しない) |

ブロック時は stderr に **(1) 推奨コマンド** (`just push`) と **(2) justfile が
未整備な場合の参照先** (`personal-docs-structure` skill の「task runner
(justfile)」節、または canonical の kawaz/bump-semver の justfile) を返す。

## 何故 `just push` を推奨するか

kawaz/* では `justfile` + `bump-semver vcs` サブコマンドを canonical に
している (canonical 実装は `kawaz/bump-semver` の `justfile`)。
`just push` ひとつで:

- `bump-semver vcs push` で jj / git の auto-dispatch
- `lint / test / validate / ci` の deps を一括実行
- `check-translations` で `*-ja.md` ↔ `*.md` の translation pair gate
- `check-version-bumped` で `bump-trigger-paths` 配下の変更時の version bump 忘れ検出
- `ensure-clean` で working tree の clean 検証

が回る。justfile の書き方は `personal-docs-structure` skill の「task runner
(justfile)」節、または canonical の kawaz/bump-semver の justfile を参照。

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
- 想定する push 受け口は `just push` のみ。他のラッパーは
  プラグイン側で許可リスト化していない (ホスト側は通すだけなので、勝手に
  独自 recipe 名を使うことは可能)

## 関連

- `~/.claude/rules/push-workflow.md` - push 後 CI watch ルール (個人ルール)
- `personal-docs-structure` skill - canonical justfile 章
- kawaz/bump-semver - canonical 実装
- kawaz/claude-cmux-msg - claude-plugin の multi-file version bump 実装例
- kawaz/claude-bash-safety - 姉妹プラグイン (backtick 誤実行検出)

## License

MIT. See [LICENSE](./LICENSE).
