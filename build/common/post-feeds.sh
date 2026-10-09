#!/bin/bash
# post-feeds.sh — feeds 安装 / 缓存恢复之后必须重放的修补(单一定义, 多处调用)
#
# 调用方: .github/workflows/compile-openwrt.yml
#   1) 「加载设置」— feeds update 之后 与 feeds install -a -f 之后 各一次(后者含 .config 反选)
#   2) 「修复缓存覆盖」— actions/cache 恢复之后
# 必须重放的原因: feeds update/install 与缓存恢复都会覆盖源码树, 之前的 sed/rm 会被还原。
#
# 铁律:
#   - 每个操作必须幂等(重复调用结果一致)
#   - 自检只做负向断言(断言"坏形态不存在"), 不绑定上游字面量; 上游改写法不得误杀编译
#   - 依赖 feeds 树的修补一律写这里, 不要再内联回 workflow
#
# 2026-10-09: 由 workflow 两处重复内联块合并而来(消除双份维护), 命令逐字保留原语义。
set -eo pipefail

cd "${Home}"

echo "== post-feeds 修补开始 (cwd: $(pwd)) =="
# fix: argon +@wget-any dep not found in LEDE openwrt-25.12
find feeds/luci package/feeds/luci package/kenzok8 -path '*/luci-theme-argon/Makefile' -exec sed -i 's/+@wget-any //g' {} + 2>/dev/null || true
find feeds/luci package/feeds/luci package/kenzok8 -path '*/luci-theme-argon/Makefile' -exec sed -i 's/+wget-any //g' {} + 2>/dev/null || true
# fix: 概览页添加编译日期（10_system.js）
BUILD_DATE=$(echo "${Compile_Date}" | perl -pe 's/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/$1.$2.$3 $4:$5/')
# 2026-09-06: 幂等注入 — 先 sed 清旧行再 perl 注入(146/260 两处执行也只留一份); 日期/作者分行显示
find feeds/luci package/feeds/luci -path '*/status/include/10_system.js' -exec sed -i "/_('Firmware Date')/d;/_('Firmware Author')/d" {} + 2>/dev/null || true
find feeds/luci package/feeds/luci -path '*/status/include/10_system.js' -exec perl -i -pe "if (/Kernel Version/ && /boardinfo\.kernel/) { s/\$/\\n\\t\\t_('Firmware Date'), '${BUILD_DATE}',\\n\\t\\t_('Firmware Author'), 'Lul1a8y',/ }" {} + 2>/dev/null || true

# 2026-09-06: 固件版本钉死 lede 风格(模板级, 不依赖 zzz 首次开机/配置保留; ${FIRMWARE_VER}=lede 上游版本号, 上游 bump 需同步)
sed -i "s/^DISTRIB_ID='%D'\$/DISTRIB_ID='LEDE'/; s/^DISTRIB_RELEASE='%V'\$/DISTRIB_RELEASE='${FIRMWARE_VER}'/; s/^DISTRIB_REVISION='%R'\$/DISTRIB_REVISION='${FIRMWARE_VER}'/; s|^DISTRIB_DESCRIPTION='%D %V %C'\$|DISTRIB_DESCRIPTION='LEDE '|" package/base-files/files/etc/openwrt_release
sed -i "s/^NAME=\"%D\"\$/NAME=\"LEDE\"/; s/^VERSION=\"%V\"\$/VERSION=\"${FIRMWARE_VER}\"/; s/^PRETTY_NAME=\"%D %V\"\$/PRETTY_NAME=\"LEDE ${FIRMWARE_VER}\"/; s/^BUILD_ID=\"%R\"\$/BUILD_ID=\"${FIRMWARE_VER}\"/; s|^OPENWRT_RELEASE=\"%D %V %C\"\$|OPENWRT_RELEASE=\"LEDE ${FIRMWARE_VER}\"|" package/base-files/files/usr/lib/os-release
grep -q "DISTRIB_DESCRIPTION='LEDE '" package/base-files/files/etc/openwrt_release || { echo "!! openwrt_release 版本钉死未生效(post-feeds)"; exit 1; }
grep -q "OPENWRT_RELEASE=\"LEDE ${FIRMWARE_VER}\"" package/base-files/files/usr/lib/os-release || { echo "!! os-release 版本钉死未生效(post-feeds)"; exit 1; }

# 2026-09-11: luci rpcd ucode 正则修正重放 — 缓存恢复会还原 feeds 源码树
# (ucode regex flag 只有 g/i/s 且 s=清 REG_NEWLINE; 加 m 会让整个 ucode 解析失败
#  → rpcd 里 luci 对象消失 → LuCI 报 -32000 Object not found。详见 diy-part.sh 同处注释)
LUCI_RPC_LUCI_R="feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci"
if [ -f "$LUCI_RPC_LUCI_R" ]; then
  sed -i 's#\$/sm#\$/#g; s#\$/s#\$/#g' "$LUCI_RPC_LUCI_R"
  # 自检(2026-09-20 改负向断言, 同 diy-part.sh 处: 不绑定上游字面量)
  if grep -qE '\$/[a-z]*[sm]' "$LUCI_RPC_LUCI_R"; then
    echo "!! luci rpcd ucode 残留 s/m flag(重放, 同 diy-part.sh 判定), 中止"; exit 1
  fi
  grep -q 'getFeatures' "$LUCI_RPC_LUCI_R" || { echo "!! luci getFeatures 段缺失(重放/上游漂移)"; exit 1; }
  echo "== luci getFeatures 正则修正重放完成 =="
fi

# 2026-09-04: 移除 defconfig 自动带入的 vsftpd(FTP)/clashoo 源 + .config 勾选
# (luci.mk i18n DEFAULT 链带入; 缓存恢复会还原源码树与 package/feeds 软链 → 必须重放)
rm -rf feeds/luci/applications/luci-app-vsftpd feeds/packages/net/vsftpd
rm -rf package/feeds/luci/luci-app-vsftpd package/feeds/packages/vsftpd
rm -rf package/kenzok8-small/clashoo package/kenzok8-small/luci-app-clashoo
sed -i '/CONFIG_PACKAGE_luci-app-vsftpd=y/d;/CONFIG_PACKAGE_vsftpd=y/d;/CONFIG_PACKAGE_luci-i18n-vsftpd-zh-cn=y/d;/CONFIG_PACKAGE_luci-app-clashoo=y/d;/CONFIG_PACKAGE_clashoo=y/d;/CONFIG_PACKAGE_luci-i18n-clashoo-zh-cn=y/d' .config 2>/dev/null || true
# 缓存恢复会带回旧 luci-app-mosdns init(带 log.size 键) → 重放剥离
MOSDNS_INIT_R="$(find package/kenzok8-small -path '*/init.d/mosdns' -print -quit 2>/dev/null || true)"
if [ -n "$MOSDNS_INIT_R" ] && [ -f "$MOSDNS_INIT_R" ]; then
  sed -i '/json_add_string "size" "\$log_size"/d' "$MOSDNS_INIT_R"
fi

# 2026-09-05: 修 mosdns stats_api —— 第一版(6d1eb4f)删错对象, run 33945234196 实测仍崩
# feeds install -a -f 日志铁证: "Overriding core package 'mosdns' with version from helloworld"
# 真正顶掉 kenzok8/small 带 stats_api 补丁版(5.3.4-r12, patches 216-222)的是 helloworld
# feed(fw876/helloworld, 5.3.4-1 仅 203-205 补丁, 无 stats_api)——旧删 coolsnowwolf
# feeds/packages/net/mosdns 只删了已被 -f 覆盖的输家副本, 固件仍编 feeds/helloworld/mosdns
# 原版 → luci-app-mosdns v1.7.12 默认生成 stats_collector{type:stats_api} → 开机 FATAL
# "plugin type stats_api not defined" crash loop (02:42 与 16:04 开机日志两次实测)
# diy-part.sh 里的 rm 跑在第140行第二次 feeds update -a 之前, 会被还原, 必须在此删
# 修: feeds install 之后删光 coolsnowwolf + helloworld 三处原版源(diy 克隆的
# package/helloworld/mosdns 一并删), 全树只留 kenzok8-small/mosdns → defconfig 唯一命中
rm -rf feeds/packages/net/mosdns package/feeds/packages/mosdns
rm -rf feeds/helloworld/mosdns package/feeds/helloworld/mosdns package/helloworld/mosdns
# 自检(防静默回归): mosdns 引擎源必须只剩 kenzok8-small(≥r12) 且 stats_api 补丁在位
# 版本不写死: 2026-09-05 晚 kenzok8/small 上游迭代到 r13, 写死 =12 曾误杀编译(run 33976091902)
if grep -qE '^CONFIG_PACKAGE_(mosdns|luci-app-mosdns)=y' .config 2>/dev/null; then
  MOSDNS_LEFT="$(find feeds package -maxdepth 6 -type f -path '*/mosdns/Makefile' 2>/dev/null || true)"
  if [ "$(printf '%s\n' "$MOSDNS_LEFT" | grep -c .)" != "1" ] || ! printf '%s\n' "$MOSDNS_LEFT" | grep -q '/kenzok8-small/mosdns/Makefile'; then
    echo "!! mosdns 源残留或缺失(应只剩 kenzok8-small/mosdns): $MOSDNS_LEFT"; exit 1
  fi
  REL_NUM="$(sed -n 's/^PKG_RELEASE:=\([0-9][0-9]*\)$/\1/p' "$MOSDNS_LEFT")"
  case "$REL_NUM" in
    ''|*[!0-9]*) echo "!! mosdns 版本无法解析: $(grep -E 'PKG_VERSION|PKG_RELEASE' "$MOSDNS_LEFT" | tr '\n' ' ')"; exit 1 ;;
  esac
  [ "$REL_NUM" -ge 12 ] || { echo "!! mosdns 版本过旧(需 kenzok8-small r12+, 实际 r$REL_NUM): $(grep -E 'PKG_VERSION|PKG_RELEASE' "$MOSDNS_LEFT" | tr '\n' ' ')"; exit 1; }
  [ -f "$(dirname "$MOSDNS_LEFT")/patches/216-plugin-add-stats_api-plugin.patch" ] || { echo "!! mosdns 缺 stats_api 补丁(216)"; exit 1; }
  echo "== mosdns 源已锁定 kenzok8-small r$REL_NUM (stats_api 补丁在位) =="
fi

# 2026-09-04: AutoUpdate init 加固 — 必须在 feeds update 之后执行(feeds 树更新会还原文件)
# 症状: 开机 S99autoupdate 报 "uci: Entry not found" + "can't open '/etc/openwrt_update'"
# 修复: uci -q 容错 + 配置补 option github + 预置 /etc/openwrt_update
AU_DIR="feeds/luci/applications/luci-app-autoupdate"
if [ -d "$AU_DIR" ] && [ -f "$AU_DIR/root/etc/init.d/autoupdate" ]; then
  sed -i 's|uci get "autoupdate\.$config_section\.github"|uci -q get "autoupdate.$config_section.github"|' "$AU_DIR/root/etc/init.d/autoupdate"
  # 幂等修正(2026-10-09): 原实现每次调用都会再插一行 option github(该文件被多处调用 → 重复累积)
  grep -q "option github 'https://github.com/Lul1a8y/AutoBuild-OpenWrt'" "$AU_DIR/root/etc/config/autoupdate" 2>/dev/null || \
    sed -i "0,/^config login/s//config login\n\toption github 'https:\/\/github.com\/Lul1a8y\/AutoBuild-OpenWrt'/" "$AU_DIR/root/etc/config/autoupdate" 2>/dev/null || true
  printf 'GITHUB_LINK="https://github.com/Lul1a8y/AutoBuild-OpenWrt"\n' > "$AU_DIR/root/etc/openwrt_update"
fi

echo "== post-feeds 修补完成 =="
