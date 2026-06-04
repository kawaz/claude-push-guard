# push 周りの justfile 移行ガイド

このファイルは `claude-push-guard` プラグインが `git push` / `jj git push` を
ブロックした時に、stderr で「これを読め」と絶対パスで指される先。

ブロックされた経緯と当面の回避策はフック本体の stderr メッセージで足りる。
ここでは **「そもそも `just push` がリポに無い」** ケースで何をすべきかを書く。

## 結論

- リポに `justfile` があるなら → `just push` (これで push 前 gate も回る)
- `justfile` が無く Makefile / package.json scripts / bin/release.sh 等で
  自作している → **kawaz/bump-semver の `justfile` を canonical テンプレ**として
  justfile を新設

`justfile` を選んでいる理由は kawaz/* 全リポで:

1. push 前の lint / test / 翻訳ペア検証 / version bump gate を **共通化** したい
2. `bump-semver vcs` サブコマンドで jj / git の auto-dispatch を効かせたい
3. `[private]` recipe で `just --list` を綺麗に保ちたい

を一括で実現するため。これは `personal-docs-structure` skill の
「task runner (justfile)」節と同じ方針。

## canonical = kawaz/bump-semver の `justfile`

新規 / 既存ともに `kawaz/bump-semver` の `justfile` をテンプレとして、
言語依存 recipe (例: `lint-go` / `lint-rust`) と version files
(`VERSION` / `Cargo.toml` / `.claude-plugin/plugin.json` 等) だけ差し替える。

主な recipe (詳細は実体を参照):

| recipe | 役割 |
|---|---|
| `push` | gate 経由で `bump-semver vcs push` |
| `ci` | lint + test (+ build) |
| `lint` | language-specific lint + `just --fmt --check` |
| `test` | テスト実行 |
| `bump-version` | `bump-semver --write` で version file 更新 + `bump-semver vcs commit` |
| `ensure-clean` | working tree clean 検証 (`bump-semver vcs is clean`) |
| `check-version-bumped` | product code 変更時に VERSION 進行を要求 |
| `check-translations` | `*-ja.md` ↔ `*.md` の鮮度 + 相互リンクヘッダ確認 |

## 既存パターン別の移行方針

### A) `justfile` が無い (Makefile / package.json scripts / bare git push)

kawaz/bump-semver の `justfile` を雛形にコピーし、`set` 系・gate 系・
`bump-semver vcs *` 呼び出しはそのまま流用、`lint`/`test`/`build` の中身と
`version-files` / `bump-trigger-paths` を各リポに合わせる。

### B) `package.json scripts` で `npm run release` 系

```json
{ "scripts": { "release": "npm test && npm run build && git push" } }
```

`npm run release` 経由でも内側の `git push` は本フックに引っかかる。
→ `justfile` 側に `push` recipe を生やすのが筋:

```just
push: ensure-clean ci check-translations check-version-bumped
    bump-semver vcs push --branch main --jj-bookmark-auto-advance
```

`npm test` / `bun run build` は recipe の cmd に直接書けばよい
(package.json scripts は残してもよいが、エントリポイントは `just push` に統一)。

参考実装: **kawaz/claude-cmux-msg** (TypeScript + claude-plugin の例)。
multi-file version bump (`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`
+ `package.json` を `bump-semver` 一発で揃える) も含まれる。

### C) Makefile / 自作シェルスクリプト (bin/release.sh など)

同様に **`justfile` にロジックを移し、シェルスクリプトは内部呼び出しに留める**。
Makefile の `.PHONY` 群を recipe に持ち上げ、依存関係 (`recipe-name: dep1 dep2`)
で表現する。複雑な多段ビルドが残るなら `scripts/` に置き recipe から呼ぶ。

### D) bare な `git push` (タスクランナー無し)

「個人 sandbox だしまだ早い」リポで `git push` を直で打ちたい場合:

1. **小規模 sandbox でも**: 最低限 `justfile` を 1 行書いて
   `push: ; bump-semver vcs push --branch main --jj-bookmark-auto-advance` を
   置くだけで価値がある (後で lint/test を生やすと自動で push gate に繋がる)
2. **本当に一時的なら**: フックを通すと困るなら、その作業の間だけ
   `~/.claude/settings.json` の `disabledPlugins` で `push-guard` を外す

## 例外メモ

- `gh pr create` / `gh pr merge` / `gh release create` などは push ではないので
  本フックは通過する (検出パターンは `git push` / `jj git push` のみ)
- コミットメッセージや heredoc 内の文字列リテラルにある "git push" は誤検知しない
  (行頭 / コマンドセパレータ直後のみマッチ)

## 関連

- `personal-docs-structure` skill - canonical justfile 章
- `~/.claude/rules/push-workflow.md` - push 後 CI watch ルール
- kawaz/bump-semver - canonical 実装 (Go、自己ドッグフーディング)
- kawaz/claude-cmux-msg - TypeScript + claude-plugin 拡張例 (multi-file version bump)
