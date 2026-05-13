#!/bin/bash
# PreToolUse(Bash) hook: git push / jj git push を直接実行させず、
# `pkf run push` 経由でのリリースワークフローに誘導する。
#
# Claude Code は Bash ツールの `command` 引数をそのまま `bash -c` に流す。
# `git push` / `jj git push` を直接打たれると、リポ側で定義した check / test /
# version bump gate / 翻訳ペア検証などをまるごとスキップしてしまう。
# 本フックは行頭またはコマンドセパレータ直後にこれらが現れたケースを exit 2 で
# ブロックし、stderr に修正方針と同梱マイグレーションガイドの絶対パスを返す。
#
# NOTE: `set -e` は使わない。フック自体の不具合 (jq 不在、JSON 不正等) は
# 通過 (exit 0) させて、ユーザの作業を巻き込まないこと。

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$command" ] || exit 0

# 行頭 / `&&` / `;` / `||` / `|` 直後の git push / jj git push のみを対象に。
# コミットメッセージや heredoc 内の文字列リテラルにある "git push" は誤検知しない。
if ! printf '%s' "$command" | grep -qE '(^|&&|;|\|\|?)\s*(git\s+push|jj\s+git\s+push)\b'; then
  exit 0
fi

HINT_FILE="$(cd "$(dirname "$0")" && pwd)/push-migration-hint.md"

cat >&2 <<EOF
BLOCK: \`git push\` / \`jj git push\` は直接実行できません。

リポ側で定義した check / test / version bump gate / 翻訳ペア検証等を
すっ飛ばさないために、以下のいずれかを使ってください:

  pkf run push          # Taskfile.pkl が定義されたリポ (推奨)
  just push             # 旧来の justfile を持つリポ

リポに pkf (Taskfile.pkl) が未整備で、justfile / Makefile / package.json scripts
等で push 周りをこねている場合は、kawaz/pkf-tasks への移行を検討してください。
移行方針と canonical テンプレ (kawaz/bump-semver) の解説は以下を参照:

  ${HINT_FILE}

このフックは PreToolUse(Bash) で exit 2 ブロック。停止後に同じ change を
別経路で再開する場合は、上記のいずれかのタスクランナー経由で push してください。
EOF
exit 2
