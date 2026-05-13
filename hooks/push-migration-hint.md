# push 周りの pkf-tasks 移行ガイド

このファイルは `claude-push-guard` プラグインが `git push` / `jj git push` を
ブロックした時に、stderr で「これを読め」と絶対パスで指される先。

ブロックされた経緯と当面の回避策はフック本体の stderr メッセージで足りる。
ここでは **「そもそも `pkf run push` がリポに無い」** ケースで何をすべきかを
書く。

## 結論

- リポに `Taskfile.pkl` があるなら → `pkf run push` (これで PR チェックも回る)
- 旧来の `justfile` しか無いなら → 当面 `just push` で良い。ただし
  kawaz/* で揃える方針なので **Taskfile.pkl へ移行する issue を起票** すること
- `Makefile` / `package.json scripts` / `bin/release.sh` 等で自作している
  → 同上、pkf に揃える

`pkf-tasks` を選んでいる理由は kawaz/* 全リポで:

1. push 前の lint / test / 翻訳ペア検証 / version bump gate を **共通化** したい
2. `kawaz.vcs.*` で jj / git の auto-dispatch を効かせたい
3. internal task (`visibility = "internal"`) で `pkf list` を綺麗に保ちたい

を一括で実現するため。これは `~/.claude/rules/docs-structure.md` の
「canonical Taskfile.pkl テンプレ」節と同じ方針。

## 既存パターン別の移行方針

### A) justfile しか無い

最頻出。canonical は **kawaz/bump-semver の `Taskfile.pkl`**。push 周りだけ
抜粋すると下記のような構造になる:

```pkl
amends "package://pkg.pkl-lang.org/github.com/mizchi/pkfire/pkfire@0.7.0#/Taskfile.pkl"
import "package://pkg.pkl-lang.org/github.com/kawaz/pkf-tasks/pkf-tasks@2.2.0#/all.pkl" as kawaz

local lint: Task = new { name = "lint"; deps { /* ... */ }; cmd = "echo lint ok"; cache = false }
local test: Task = new { name = "test"; deps { lint }; cmd = "<test cmd>" }
local build: Task = new { name = "build"; deps { lint }; cmd = "<build cmd>" }
local ci: Task = new { name = "ci"; deps { lint; test; build }; cmd = "echo ci ok"; cache = false }

local checkVersionBumped: Task = (kawaz.semver.checkBumped) {
  compareRefCmd = "echo main@origin"
  triggerPaths = List("src/")
  versionFiles = List("VERSION")
  taskName = "semver:check-version-bumped"
}.check

local push: Task = (kawaz.vcs.push) {
  name = "push"
  deps { ci; kawaz.docs.checkTranslations; checkVersionBumped;
         kawaz.migrate.checkPkfTasks; kawaz.migrate.checkPkfire }
}

tasks {
  push; ci; build; lint; test
  ...kawaz.vcs.allTasks; ...kawaz.docs.allTasks
  checkVersionBumped; ...kawaz.migrate.allTasks
}
```

justfile からの移植要点 (詳細は `~/.claude/rules/docs-structure.md`):

| justfile | Taskfile.pkl |
|---|---|
| `set unstable` + `is-jj` / `is-git` shell var | `kawaz.vcs.*` (auto-dispatch 内蔵) |
| `ensure-clean` recipe | `kawaz.vcs.ensureClean` task |
| `check-translations` recipe | `kawaz.docs.checkTranslations` (umbrella) |
| `check-version-bumped` ([script] 内 diff) | `kawaz.semver.checkBumped` を `.check` で取り出す |
| `bump-version bump="patch"` | `local bumpVersion: Task` (Param で typed enum、引数名は `level`) |
| `default:` (`@just --list --unsorted` wrapper) | `default` task (`acceptsArgs = true` + `./bin/<TOOL> "$@"`) |

justfile は v2.2.0 で **廃止** (Taskfile.pkl 単独運用) するのが kawaz 標準。

### B) package.json scripts で `npm run release` 系

```json
{
  "scripts": {
    "build": "...",
    "test": "...",
    "release": "npm test && npm run build && git push"
  }
}
```

`npm run release` 経由でも `git push` は本フックに引っかかる (中で `bash -c`
で `git push` を呼ぶ場合も親プロセスは Claude の Bash tool なので)。

→ **Taskfile.pkl 側に push task を生やす** のが筋:

```pkl
local test: Task = new { name = "test"; cmd = "bun test" }
local build: Task = new { name = "build"; deps { test }; cmd = "bun run build" }
local push: Task = (kawaz.vcs.push) { name = "push"; deps { build } }
```

`bun run build` / `npm test` は cmd に直接書いて良い (package.json scripts は
残しても良いが、エントリポイントは `pkf run push` に統一)。

参考実装: **kawaz/claude-cmux-msg** (TypeScript + claude-plugin の例)。
multi-file version bump (`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`
+ `package.json` を `bump-semver` 一発で揃える) も含まれる。

### C) Makefile / 自作シェルスクリプト (bin/release.sh など)

同様に **Taskfile.pkl にロジックを移し、シェルスクリプトは内部呼び出しに留める**。
Makefile の `.PHONY` 群を Task の cmd に持ち上げ、依存関係 (`deps`) は
Taskfile.pkl の `deps { ... }` で表現する。

複雑な多段ビルドが残るなら、シェルスクリプトは `scripts/` に残して
Task の cmd から呼ぶ形が綺麗。

### D) bare な `git push` (タスクランナー無し)

「個人 sandbox だしまだ早い」リポで `git push` を直で打ちたい場合:

1. **小規模 sandbox なら**: それでも `git push` を直接打つ運用は弱い。最低限
   `Taskfile.pkl` を 5 行書いて `push: kawaz.vcs.push` を呼ぶだけでも価値がある
   (今後 lint/test を生やした時に push gate に自動接続される)
2. **本当に一時的なら**: フックを通すと困るなら、その作業の間だけ
   `~/.claude/settings.json` の `disabledPlugins` (or 個別 disable) で
   `push-guard` を外す

## 例外メモ

- `gh pr create` / `gh pr merge` / `gh release create` などは push ではない
  ので本フックは通過する (検出パターンは `git push` / `jj git push` のみ)
- コミットメッセージや heredoc 内の文字列リテラルにある "git push" は
  誤検知しない (行頭 / コマンドセパレータ直後のみマッチ)

## 関連

- `~/.claude/rules/docs-structure.md` - canonical Taskfile.pkl テンプレ章
- `~/.claude/rules/push-workflow.md` - push 後 CI watch ルール
- kawaz/bump-semver - canonical 実装 (Go、自己ドッグフーディング)
- kawaz/claude-cmux-msg - TypeScript + claude-plugin 拡張例
- kawaz/pkf-tasks - 共通 task module 本体
