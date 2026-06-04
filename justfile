# claude-push-guard justfile
#
# kawaz/* リポの共通テンプレ (kawaz/bump-semver justfile が canonical) に揃えてある。
# shell + JSON manifest のみのプラグインなので、lint / test / push に絞った構造。
# VCS 操作 (clean 判定 / diff / push / commit) と翻訳鮮度チェックは bump-semver vcs
# サブコマンドに委譲し、jj/git 分岐の手書きを撲滅する。
# 構造変更は bump-semver 側を先に直してからこちらへ追従する。

# ---------- settings ----------

set unstable
set guards
set lazy
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

set script-interpreter := ["bash", "-eu", "-o", "pipefail"]

# bump-version トリガとなる product code パス (docs/ や *.md は除外)。

bump-trigger-paths := "hooks/ tests/"

# bump 対象の version ファイル群 (claude-plugin 固有: 2 ファイルの version 一致は bump-semver が保証)

version-files := ".claude-plugin/plugin.json .claude-plugin/marketplace.json"

# ---------- default ----------

# レシピ一覧を表示
default:
    @just --list --unsorted

# ---------- main entries (利用者が直接叩く) ----------

# push (バージョン bump 済みを前提、全 gate 通過後に push)
push: ensure-clean ci check-translations check-versions check-version-bumped
    bump-semver vcs push --branch main --jj-bookmark-auto-advance

# push (ドキュメント更新等のみで bump 不要な場合)
push-without-bump: ensure-clean ci check-translations check-versions
    bump-semver vcs push --branch main --jj-bookmark-auto-advance

# version を bump して Release commit を作成 (push は別途 `just push`)
[script]
bump-version bump="patch": ensure-clean
    new_version=$(bump-semver {{ bump }} {{ version-files }} --write --no-hint)
    bump-semver vcs commit -m "Release v${new_version}" {{ version-files }}

# CI 単一エントリ (lint + test + validate を依存重複排除で 1 回ずつ保証)
ci: lint test validate

# ---------- dev recipes (push/ci の依存、利用者が直接叩くこともある) ----------

# lint: justfile フォーマット + shell 構文 + JSON validity + version 一致
lint: lint-just lint-shell lint-json lint-version-sync

# justfile フォーマット確認
[private]
lint-just:
    just --fmt --check --unstable

# bash -n on hooks/*.sh and tests/*.sh
[private]
lint-shell:
    for f in hooks/*.sh tests/*.sh; do [ -f "$f" ] || continue; bash -n "$f"; done

# jq . on plugin/marketplace/hooks JSON manifests
[private]
lint-json:
    for f in .claude-plugin/*.json hooks/*.json; do [ -f "$f" ] || continue; jq . "$f" > /dev/null; done

# plugin.json と marketplace.json の version 一致を保証 (bump-semver 内部の整合チェック)
[private]
lint-version-sync:
    @bump-semver get {{ version-files }} --no-hint > /dev/null

# Claude Plugin の構造検証 (marketplace 自己宣言含む)
validate: lint
    claude plugin validate .

# push-guard.sh integration test
test: lint
    bash tests/push-guard.test.sh

# 現在の version を表示 (2 ファイルの一致確認も兼ねる)
version:
    @bump-semver get {{ version-files }} --no-hint

# ---------- gates (push の内部、利用者が直接叩くことほぼなし) ----------

# ワーキングコピーがクリーン (jj は @ が empty、git は porcelain 空)
ensure-clean: lint
    bump-semver vcs is clean

# version files 整合チェック (bump-semver get の副作用で一致検証)
[private]
check-versions:
    @bump-semver get {{ version-files }} --no-hint > /dev/null

# 翻訳ペア (README.md ↔ README-ja.md) の鮮度: en の最終 commit timestamp >= ja
[private]
check-translations: ensure-clean check-translation-freshness (_check-translation-headers "README")

[private]
check-translation-freshness:
    bump-semver vcs outdated 'glob:**/*-ja.md' '$1/$2.md'

# 相互リンクヘッダの確認 (vcs outdated は timestamp のみ検証するので grep は別途)
[private]
_check-translation-headers name:
    ?test -f {{ name }}-ja.md
    test -f {{ name }}.md
    head -5 {{ name }}-ja.md | grep -qF "> [English](./{{ file_name(name) }}.md) | 日本語"
    head -5 {{ name }}.md    | grep -qF "> English | [日本語](./{{ file_name(name) }}-ja.md)"

# product code に変更があれば version も main@origin より bump 済か検証 (変更なしならスキップ)
[private]
[script]
check-version-bumped:
    rc=0
    bump-semver vcs diff -q main@origin -- {{ bump-trigger-paths }} || rc=$?
    case "$rc" in
      0) exit 0 ;;
      1) ;;
      *) echo "ERROR: bump-semver vcs diff failed (rc=$rc). main@origin が track されていない可能性。先に 'jj git fetch' を試してください" >&2; exit 1 ;;
    esac
    bump-semver compare gt .claude-plugin/plugin.json vcs:main@origin:.claude-plugin/plugin.json --no-hint && exit 0
    echo 'ERROR: bump-trigger-paths が変わってるが version 未 bump。"just bump-version" を実行してください' >&2
    exit 1
