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
    if grep -nE '^[[:space:]]*\.[[:space:]]*(#|$)' "$f"; then
        echo "!! $f 含无文件名的 source 命令"
        status=1
    fi
done

echo "== shellcheck -S error =="
if command -v shellcheck >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    shellcheck -S error $files || status=1
    # 2026-11-01: warning 级别先作为可见的 advisory, 不阻断历史脚本(存量较多);
    # 新代码仍应尽量清零。真正阻断的是上面的 error 级别。
    # shellcheck disable=SC2086
    shellcheck -S warning -f gcc $files > /tmp/shellcheck-warnings.txt 2>&1 || true
    if [ -s /tmp/shellcheck-warnings.txt ]; then
        echo "== shellcheck warnings (advisory): $(wc -l < /tmp/shellcheck-warnings.txt) 条 =="
        head -20 /tmp/shellcheck-warnings.txt
    fi
else
    echo "shellcheck 未安装, 跳过"
fi

echo "== actionlint =="
if command -v actionlint >/dev/null 2>&1; then
    # 内联 shell 交给 actionlint 调用的 shellcheck; 只报 error, 避免历史 warning 阻断。
    SHELLCHECK_OPTS="-S error" actionlint || status=1
else
    echo "!! actionlint 未安装 (CI 应安装; 本地请装 actionlint)"
    status=1
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
    # 工作区(含未提交改动)始终检查; 不能只在 base...HEAD 或 HEAD^ 上检查,
    # 否则本地 lint 在提交前是空操作。
    git diff --check || status=1
    if [ -n "${BASE_SHA:-}" ] && git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
        git diff --check "${BASE_SHA}"...HEAD || status=1
    elif git rev-parse --verify HEAD^ >/dev/null 2>&1; then
        # 手动触发/无 base 时至少检查最后一次提交。
        git diff --check HEAD^ HEAD || status=1
    else
        echo "没有可比较的父提交, 跳过提交范围检查"
    fi
fi

if [ "$status" -ne 0 ]; then
    echo "!! lint 失败"
    exit 1
fi
echo "== lint 通过 =="
