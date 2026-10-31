#!/bin/sh
# 快速静态检查, 目标是在 5 小时编译前抓住语法/明显错误。
# 本地: ./scripts/lint.sh   CI: .github/workflows/lint.yml
set -eu

cd "$(dirname "$0")/.."

status=0
# 常规 *.sh 之外，UCI defaults 和部分启动脚本没有 .sh 后缀，也要检查。
files="$(
    {
        find . -path ./.git -prune -o -type f -name '*.sh' -print
        find build -path '*/files/etc/uci-defaults/*' -type f -print
        printf '%s\n' \
            build/Lede_source/files/usr/sbin/app \
            build/common/LIENOL/diy/package/base-files/files/etc/profile \
            build/common/MORTAL/diy/package/base-files/files/etc/profile
    } | sort -u
)"

echo "== bash -n =="
for f in $files; do
    bash -n "$f" || status=1
done

echo "== standalone '.' (source without filename) =="
# 2026-10-28: post-feeds.sh 曾出现行首单独的 "."，bash 在 set -e 下直接 rc=2；
# bash -n 抓不到，这里显式扫描。
for f in $files; do
    if grep -nE '^[[:space:]]+\.[[:space:]]*(#|$)' "$f"; then
        echo "!! $f 含无文件名的 source 命令"
        status=1
    fi
done

echo "== shellcheck -S error =="
if command -v shellcheck >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    shellcheck -S error $files || status=1
else
    echo "shellcheck 未安装, 跳过"
fi

echo "== actionlint =="
if command -v actionlint >/dev/null 2>&1; then
    actionlint || status=1
else
    echo "actionlint 未安装, 跳过"
fi

echo "== JSON =="
if command -v jq >/dev/null 2>&1; then
    json_files="$(git ls-files '*.json' 2>/dev/null || true)"
    if [ -n "$json_files" ]; then
        # shellcheck disable=SC2086
        jq empty $json_files || status=1
    else
        echo "没有跟踪的 JSON 文件, 跳过"
    fi
else
    echo "jq 未安装, 跳过"
fi

echo "== git diff --check =="
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --check || status=1
fi

if [ "$status" -ne 0 ]; then
    echo "!! lint 失败"
    exit 1
fi
echo "== lint 通过 =="
