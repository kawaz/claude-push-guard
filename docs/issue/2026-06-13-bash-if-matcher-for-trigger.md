# 検討: PreToolUse の `if` field (Bash matcher) で push 検知の堅牢化余地があるか

> 本リポは `docs/issue/` 未採用だったため、本 issue 起票に合わせて新設 (= 最初の commit で作成)。
> 起票者は **部外者セッション** (claude-plugin-reference のメンテパスで CC 新機能を検証中に発見)。
> **実装方針は当事者であるこのリポのセッションが判断してください。** 下記はあくまで「使えるかも」の
> フラグと、賢さ/限界の確認先の提示です。鵜呑みにせず一次資料で裏取りした上で要否を決めてください。

## 背景 (= なぜフラグするか)

現状 `hooks/push-guard.sh` は、全 Bash command に対して自前 regex で push を検知している:

```
grep -qE '(^|&&|;|\|\|?)\s*(git\s+push|jj\s+git\s+push)\b'
```

Claude Code には PreToolUse hook の **`if` field** があり、`Bash(<glob>)` 形式で指定すると
**ランタイムが shell 構文を解析してサブコマンド単位で判定**する (単純な文字列 glob ではない)。
コマンド名止まりのパターン (`Bash(git *)`) は、leading の `VAR=value` 除去・`$()`/backtick 内の
サブコマンド判定までやってくれる。この賢さを使えば、自前 regex の取りこぼし/誤爆を減らせる可能性がある。

## 実際に踏んだ自前 regex の false positive (= 動機になった実例)

claude-plugin-reference のメンテ中、次の **grep コマンド**が push-guard にブロックされた:

```
grep -nE 'grep|jj git push|git push|sed|awk' hooks/*.sh | head
```

これは `git push` を実行していない。しかし単一引用符内の regex 文字列
`'...jj git push|git push|...'` に含まれる `|git push` を、現行 regex の `(\|\|?)\s*git\s+push`
節が「パイプ後の git push」と誤認して発火した。**文字列リテラルとシェル構文を regex で
区別できない**典型例。`if: "Bash(git push *)"` のように shell 構文解析に委ねれば、
引用符内文字列は実コマンドとして扱われないので、この種の誤爆を避けられる見込み。

## 検討してほしいこと (= 判断は当事者セッションで)

- `if` field を「第1段フィルタ」として使い、script 起動自体を絞れるか / 絞るべきか
- そもそも全置換できるのか、それとも script 側の検査は残すのか
  (push-guard は「検知」だけなので、`gh-issue-guard` 等と違い起動可否=ブロック可否に近い。
   置換余地は相対的に大きいかもしれないが、判断は実装責務を持つこちらで)
- **限界の確認が必須**: コマンド名より深いパターン (`Bash(git push *)`) は `$()`/`$VAR`/
  パース不能なコマンドに対して **fail-open (保守的に発火)** する。guard 用途では過剰発火は
  安全側だが、「`if` だけで完璧に絞れる」前提は置けない。`if` の正確な挙動・厳密判定が効く条件・
  fail-open になる条件は推測せず一次資料で確認すること

## 一次資料 (= 賢さと限界の正本。ここで裏取りする)

- `kawaz/claude-plugin-reference` の `skills/claude-plugin-reference/reference/hooks.md` §3
  「`if` field」節:
  - `Bash(...)` パターンの実コマンドマッチ挙動 [実機検証済: v2.1.170] — サブコマンド単位判定の
    実測マトリクス、fail-open 条件
  - `if` の適用可能 event (blockable event 限定: PreToolUse 等) / バージョン (v2.1.85+)

実機で push-guard の対象ケース (`jj git push` / `FOO=bar git push` / heredoc 内文字列 /
引用符内文字列) を `if` でどう判定するか自分で観測してから採否を決めるのが安全。

## 優先度

**低〜中**。現行 regex で実害は出ていない (誤爆は稀)。ただし上記 false positive のように
「文字列リテラル中の push 風文字列」を踏む余地はあるので、堅牢化の investment として検討の価値あり。
急がない。

## 参考

- 一次資料: `kawaz/claude-plugin-reference` `reference/hooks.md` §3
- 起票元の経緯: claude-plugin-reference `docs/journal/2026-06-13-cc-v2.1.177-maintenance.md`
- ルール: kawaz `dogfooding-feedback-upstream` (利用側で気づいた上流改善余地は owning repo に還元する)

報告者: claude-plugin-reference メンテパス (部外者セッション)。2026-06-13。
