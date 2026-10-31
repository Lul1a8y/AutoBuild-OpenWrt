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
  # 2026-10-24: 三处仓库地址原来写死成 Lul1a8y/AutoBuild-OpenWrt(fork/改名场景会出现
  # "LuCI 查新仓库、固件下旧仓库"的双源)。改为优先用构建期 env 的 Github(workflow :13
  # 就是 ${{github.repository}}), 本地手工跑时退回默认值。
  FW_GITHUB="${Github:-https://github.com/Lul1a8y/AutoBuild-OpenWrt}"
  FW_GITHUB="${FW_GITHUB%/}"
  grep -q "option github '${FW_GITHUB}'" "$AU_DIR/root/etc/config/autoupdate" 2>/dev/null || \
    sed -i "0,/^config login/s##config login\n\toption github '${FW_GITHUB}'#" "$AU_DIR/root/etc/config/autoupdate" 2>/dev/null || true
  # 2026-10-22: 之前这里只写 GITHUB_LINK 一行, 把 RELEASE_DOWNLOAD 弄丢了。
  # luci-app-autoupdate 的 /usr/bin/AutoUpdate 要求 GITHUB_LINK 与 RELEASE_DOWNLOAD 同时存在,
  # 否则 Remote_detection 直接 `TIME r "缺少openwrt_update文件"` 退出 ——
  # 实测设备上 `AutoUpdate -c` 报这个错、rc=1, LuCI 的"检查更新/一键升级"整条链路是死的。
  # 2026-10-22(二): 只有 GITHUB_LINK + RELEASE_DOWNLOAD 还不够 —— Remote_information 拼的
  # 匹配正则要用 LUCI_EDITION/SOURCE/DEVICE_MODEL/FIRMWARE_SUFFIX/TARGET_BOARD/FIRMWARE_VERSION,
  # 缺一个就是 "获取固件信息失败"。上游 281677160 是构建期把 9 行全写死; 这里改成运行时从
  # /bin/openwrt_info 派生(source 之后就有 CURRENT_Version/LUCI_Name/REPO_Name/
  # DEFAULT_Device/Firmware_Type), 换目标板、换分支都不用手改。
  # 2026-10-24(二): RELEASE_DOWNLOAD 改成由 GITHUB_LINK 派生 —— 包内 init 脚本在 LuCI 里
  # 改仓库地址时只 sed 了 GITHUB_LINK 那一行, 派生写法能让下载地址自动跟着走。
  {
    cat <<'AU_UPDATE_EOF'
GITHUB_LINK="@@FW_GITHUB@@"
GITHUB_PROXY=""
RELEASE_DOWNLOAD="${GITHUB_LINK}/releases/download/AutoUpdate"
AU_UPDATE_EOF
    cat <<'AU_UPDATE_EOF'
# 以下 6 项由 /bin/openwrt_info 派生(构建期 build/common/upgrade.sh 的 Diy_Part2 生成)
[ -f /bin/openwrt_info ] && . /bin/openwrt_info
FIRMWARE_VERSION="${CURRENT_Version}"
LUCI_EDITION="${LUCI_Name}"
SOURCE="${REPO_Name}"
DEVICE_MODEL="${DEFAULT_Device}"
FIRMWARE_SUFFIX=".${Firmware_Type#.}"
TARGET_BOARD="${DEFAULT_Device%%-*}"
AU_UPDATE_EOF
  } | sed "s|@@FW_GITHUB@@|${FW_GITHUB}|g" > "$AU_DIR/root/etc/openwrt_update"
  grep -q "^GITHUB_LINK=\"${FW_GITHUB}\"$" "$AU_DIR/root/etc/openwrt_update" || { echo "!! openwrt_update 的 GITHUB_LINK 未按构建仓库写入"; exit 1; }
  for k in GITHUB_LINK RELEASE_DOWNLOAD FIRMWARE_VERSION LUCI_EDITION SOURCE DEVICE_MODEL FIRMWARE_SUFFIX TARGET_BOARD; do
    grep -q "^${k}=" "$AU_DIR/root/etc/openwrt_update" || { echo "!! openwrt_update 缺少 ${k}(升级链路会在这一步中止)"; exit 1; }
    # 2026-10-22: 只查"键在"不够 —— 运行时派生那 6 项在 /bin/openwrt_info 缺失时会展开成空串,
    # 键仍在、值全空, 设备端正则永远匹配不到云端固件。GITHUB_PROXY 本来就该为空, 不查。
    [ "$k" = "GITHUB_PROXY" ] || grep -qE "^${k}=\".+\"" "$AU_DIR/root/etc/openwrt_update" || { echo "!! openwrt_update 的 ${k} 为空(升级匹配会失效)"; exit 1; }
  done
fi

# 2026-10-21: 修 dnsmasq 在 ujail 里看不到 passwall 的 ACL conf-dir
# 症状: passwall 用 dns_shunt=dnsmasq 时 dnsmasq crash loop, 日志
#   cannot access directory /tmp/etc/passwall/acl/default/dnsmasq.d: No such file or directory
#   FAILED to start up        (procd 每 5s 重启, 连崩 6 次放弃 → 全屋 DNS 挂)
# 根因: passwall 用 uci add_list dhcp.@dnsmasq[0].addnmount=... 把 ACL 目录交给 dnsmasq,
#   但这份 dnsmasq.init 没有 addnmount 钩子(上游 openwrt master 有:
#   config_list_foreach "$cfg" addnmount append_extramount)。于是 ujail 从不挂载该目录,
#   dnsmasq 在 jail 里读到 conf-dir 指向不存在的路径 → 拒绝启动。
#   实测: 同一份 conf 在宿主 root 下 dnsmasq --test 通过, 只有 jail 里失败。
# 修: 补回上游钩子; 额外加"先建目录再挂载" —— 开机时 passwall 还没建 ACL 目录时,
#   光 return 0 只是不挂载, dnsmasq 进 jail 后照样读不到 conf-dir、照样起不来;
#     mkdir -p 之后再挂, 挂载源与 conf-dir 同时成立。已存在(含指向真实目录的软链)时无副作用。
DNSMASQ_INIT="package/network/services/dnsmasq/files/dnsmasq.init"
[ -f "$DNSMASQ_INIT" ] || { echo "!! 找不到 ${DNSMASQ_INIT}(dnsmasq 包结构变了?), addnmount 补丁没地方打"; exit 1; }
if ! grep -q 'config_list_foreach "$cfg" addnmount' "$DNSMASQ_INIT"; then
  grep -q '^append_extramount()' "$DNSMASQ_INIT" || \
    perl -0pi -e 's/^append_addnhosts\(\) \{/append_extramount() {\n\t[ -n "\$1" ] || return 0\n\tmkdir -p "\$1" 2>\/dev\/null\n\tismounted "\$1" || append EXTRA_MOUNT "\$1"\n}\n\nappend_addnhosts() {/m' "$DNSMASQ_INIT"
  perl -0pi -e 's/^\tprocd_open_instance \$cfg$/\tconfig_list_foreach "\$cfg" addnmount append_extramount\n\n\tprocd_open_instance \$cfg/m' "$DNSMASQ_INIT"
fi
# 自检(负向): 函数体与调用都必须就位。上游 dnsmasq.init 换结构时这里立刻中止,
# 而不是"补丁静默没打上、编出来的固件照样每 5 秒崩一次"。
grep -q '^append_extramount()' "$DNSMASQ_INIT" || { echo "!! append_extramount 未插入(上游 dnsmasq.init 结构变了?)"; exit 1; }
grep -q 'config_list_foreach "$cfg" addnmount append_extramount' "$DNSMASQ_INIT" || { echo "!! addnmount 调用未插入(procd_open_instance 那行变了?)"; exit 1; }
sh -n "$DNSMASQ_INIT" || { echo "!! dnsmasq.init 打补丁后语法错误"; exit 1; }
echo "== dnsmasq init 已补 addnmount 钩子(ujail 可见 passwall ACL 目录) =="

# 2026-10-22: 固件升级前强制验签 —— 补丁要打在"实际执行的那份"脚本上
# 背景: 2026-10-21 的验签代码写进了 build/common/AutoUpdate.sh(经 common.sh 拷进
#   package/base-files/files/bin)。但 luci-app-autoupdate 包自带 root/usr/bin/AutoUpdate,
#   安装顺序在 base-files 之后 → 把加固版覆盖掉。实测刷了 202610212346 的机器上
#   /usr/bin/AutoUpdate 仍是包里的 12971 字节旧脚本(无验签、MD5 比对失败只打印不退出)。
#   于是发布端生成的 .sha256.sig 白生成了。
# 修: 直接patch包内那份脚本, 在下载校验之后、sysupgrade 之前插入强制验签。
AU_PKG="feeds/luci/applications/luci-app-autoupdate"
AU_BIN="$AU_PKG/root/usr/bin/AutoUpdate"
# REGULAR_UPDATE!=true 时这个包根本不会被 clone, 整块跳过(不是缺陷);
# 但只要包在, 脚本结构不认识就立刻中止 —— 不允许"验签补丁静默没打上"。
# 2026-10-22: 再收紧一层 —— 声明要发布升级链路(REGULAR_UPDATE=true)却找不到包, 也必须红,
# 否则会出现"工作流照样出 .sig、设备端根本没有验签代码"的组合。
if [ "${REGULAR_UPDATE}" = "true" ] && [ ! -d "$AU_PKG" ]; then
  echo "!! REGULAR_UPDATE=true 但 ${AU_PKG} 不存在, 验签补丁没地方打"
  exit 1
fi
if [ -d "$AU_PKG" ]; then
[ -f "$AU_BIN" ] || { echo "!! 找不到 ${AU_BIN}(luci-app-autoupdate 结构变了?), 升级验签补丁没地方打"; exit 1; }

# 2026-10-31(BUILD-1): AutoUpdate 的验签/运行路径直接调用 /usr/bin/openssl,
# 但 luci-app-autoupdate 的 LUCI_DEPENDS 没声明 openssl-util。构建期检查只能
# 证明工具链里有, 不能保证目标镜像装上; 这里把依赖补进包元数据并回读断言。
AU_MAKE="$AU_PKG/Makefile"
[ -f "$AU_MAKE" ] || { echo "!! 找不到 ${AU_MAKE}, 无法补 openssl-util 依赖"; exit 1; }
grep -q '^LUCI_DEPENDS:=' "$AU_MAKE" || {
  echo "!! ${AU_MAKE} 缺少 LUCI_DEPENDS, 无法补 openssl-util 依赖"; exit 1
}
if ! grep -q '^LUCI_DEPENDS:=.*+openssl-util' "$AU_MAKE"; then
  sed -i 's/^LUCI_DEPENDS:=/LUCI_DEPENDS:=+openssl-util /' "$AU_MAKE"
fi
grep -q '^LUCI_DEPENDS:=.*+openssl-util' "$AU_MAKE" || {
  echo "!! luci-app-autoupdate 的 LUCI_DEPENDS 未包含 openssl-util"; exit 1
}
echo "== luci-app-autoupdate 已声明 openssl-util 依赖 =="

# 2026-10-31: LuCI 检查/升级按钮会 `rm -f ... /tmp/autoupgrade.*`, 这个通配把
# AutoUpdate 自己的 flock 锁文件(/tmp/autoupgrade.lock)也删了。锁的是 inode, 删掉后
# 新进程会新建一个 inode 再拿到锁 —— cron 正在升级时点「检查」, 就会再起一个
# AutoUpdate, 两个进程同时对同一路径 sysupgrade -b/-f, 备份损坏甚至双写 flash。
# 只删状态文件, 保留锁文件。
AU_CTL="$AU_PKG/luasrc/controller/autoupdate.lua"
if [ -f "$AU_CTL" ]; then
  if grep -q 'rm -f /tmp/compare_version /tmp/autoupdate\.lock /tmp/autoupgrade\.\*' "$AU_CTL"; then
    sed -i 's#rm -f /tmp/compare_version /tmp/autoupdate\.lock /tmp/autoupgrade\.\*#rm -f /tmp/compare_version /tmp/autoupgrade.pid /tmp/autoupgrade.exitcode /tmp/autoupgrade.log /tmp/autoupdate.log#' "$AU_CTL"
  fi
  grep -q 'rm -f /tmp/compare_version /tmp/autoupgrade\.pid' "$AU_CTL" || {
    echo "!! ${AU_CTL} 的清理行不是预期形态, 无法保留 autoupgrade.lock"; exit 1
  }
  if grep -q 'rm -f /tmp/compare_version /tmp/autoupdate\.lock /tmp/autoupgrade\.\*' "$AU_CTL"; then
    echo "!! ${AU_CTL} 仍会删除 autoupgrade.lock(并发升级风险)"; exit 1
  fi
  echo "== luci-app-autoupdate 控制器不再删除升级锁 =="
fi

# 2026-10-30: 上游会通过 /tmp/autoupgrade.pid + ps|grep 全局结束 wget/uclient-fetch/curl,
# 可能误杀订阅/规则下载等无关进程; 改成 mkdir 互斥锁, 不再按进程名杀。
if ! grep -q 'AUTOUPGRADE_LOCK' "$AU_BIN"; then
  grep -q '^Select=""$' "$AU_BIN" || { echo "!! ${AU_BIN} 缺少 Select 锚点, 无法插入升级互斥锁"; exit 1; }
  awk '!done && /^Select=""$/ {
    print
    print ""
    print "# 2026-10-30: 升级互斥; 用 flock 原子加锁, 避免 mkdir/rm 的毫秒级竞态。"
    print "AUTOUPGRADE_LOCK=\"/tmp/autoupgrade.lock\""
    print "if command -v flock >/dev/null 2>&1; then"
    print "    exec 9>\"$AUTOUPGRADE_LOCK\""
    print "    flock -n 9 || { echo \"另一个 AutoUpdate 正在运行\" >&2; exit 1; }"
    print "else"
    print "    AUTOUPGRADE_LOCK_DIR=\"/tmp/autoupgrade.lock.d\""
    print "    mkdir \"$AUTOUPGRADE_LOCK_DIR\" 2>/dev/null || { echo \"另一个 AutoUpdate 正在运行\" >&2; exit 1; }"
    print "    trap \"rmdir /tmp/autoupgrade.lock.d 2>/dev/null\" EXIT"
    print "    trap \"rmdir /tmp/autoupgrade.lock.d 2>/dev/null; exit 130\" INT TERM"
    print "fi"
    done=1
    next
  }
  { print }' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"
fi
grep -q 'flock -n 9' "$AU_BIN" || { echo "!! 包内 AutoUpdate 的 flock 互斥未插入"; exit 1; }

if grep -q 'autoupgrade.pid' "$AU_BIN"; then
  perl -0pi -e 's{    # 清理下载进程\n    if \[ -f "/tmp/autoupgrade\.pid" \]; then\n.*?\n    fi\n}{    # 2026-10-30: 不再全局结束 wget/uclient-fetch/curl; 互斥锁已防止并发。\n}s' "$AU_BIN"
fi
if grep -q 'autoupgrade.pid' "$AU_BIN"; then
  echo "!! 包内 AutoUpdate 仍保留按进程名杀下载的逻辑"
  exit 1
fi

# 2026-10-23: BOOT_TYPE 按发布名精确映射(不是简单大写化)。
# 上游脚本按 x86 + /sys/firmware/efi 判出小写 uefi/legacy/sysupgrade, 而本仓库发布名
# 是 -UEFI- / -Legacy- / -Sysupg-(build/common/upgrade.sh:131/137/149), grep -E 大小写敏感。
# 早先的 tr a-z A-Z 只能让 UEFI 对上, Legacy/Sysupg 被大写化后反而永久失配。
if ! grep -q 'BOOT_TYPE 精确映射' "$AU_BIN"; then
  grep -q '^    # 定义正则表达式以匹配固件信息$' "$AU_BIN" || { echo "!! ${AU_BIN} 缺少正则锚点(BOOT_TYPE 没法映射)"; exit 1; }
  awk '!done && /^    # 定义正则表达式以匹配固件信息$/ {
         print "    # 2026-10-23: BOOT_TYPE 精确映射 —— 发布名是 -UEFI-/-Legacy-/-Sysupg-, grep -E 区分大小写,"
         print "    # 整体大写化只会让 UEFI 对上, 另外两种永远匹配不到云端固件。"
         print "    case \"$BOOT_TYPE\" in"
         print "        uefi|UEFI) BOOT_TYPE=UEFI ;;"
         print "        legacy|Legacy|LEGACY) BOOT_TYPE=Legacy ;;"
         print "        sysupgrade|Sysupg|SYSUPGRADE) BOOT_TYPE=Sysupg ;;"
         print "    esac"
         done=1
       } { print }' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"
fi
grep -q '^        sysupgrade|Sysupg|SYSUPGRADE) BOOT_TYPE=Sysupg ;;$' "$AU_BIN" || { echo "!! BOOT_TYPE 精确映射补丁未生效"; exit 1; }

# 2026-10-22: 作废"MD5 片段比对"。原逻辑拿 md5[0:3]+sha256[0:3] 去比文件名里嵌的片段,
# 本仓库固件名是 12 位 sha256 前缀(d146ff09ce51) → 两者恒不等 → 每次升级都在这里
# 被 TIME r(= exit 1) 中止, 后面的验签段根本走不到。完整性改由验签段(openssl 验签 +
# 全量 sha256 比对)负责, 这里只保留 chmod。
if ! grep -q '完整性已由签名段覆盖' "$AU_BIN"; then
  perl -0pi -e 's{    # 计算本地固件的 MD5 和 SHA256 组合值.*?        TIME g "MD5对比成功"\n    fi\n}{    # 2026-10-22: 原 MD5 片段比对假设文件名里嵌 md5[0:3]+sha256[0:3], 本仓库是 12 位 sha256\n    # 前缀(d146ff09ce51), 两者恒不等 → 每次升级都在这里被 TIME r(=exit 1) 中止。\n    # 完整性已由签名段覆盖(openssl 验签 + 全量 sha256 比对), 这里只补 chmod。\n    chmod 755 "\$DOWNLOAD_PATH/\$REMOTE_FIRMWARE"\n}s' "$AU_BIN"
  grep -q '完整性已由签名段覆盖' "$AU_BIN" || { echo "!! MD5 片段比对作废失败(上游脚本改了?)"; exit 1; }
fi

if ! grep -q 'firmware-signing.pub' "$AU_BIN"; then
  grep -q '^    # 移除 gzip 包$' "$AU_BIN" || { echo "!! ${AU_BIN} 缺少 '移除 gzip 包' 锚点(上游脚本改了?)"; exit 1; }
  PW_BLK=$(mktemp)
  cat > "$PW_BLK" <<'PW_SIGN_EOF'
    # 2026-10-22: 升级前强制验签。清单 <固件>.sha256 的 Ed25519 签名必须通过,
    # 且固件实算 SHA256 必须与清单一致; 任何一项不满足直接中止(TIME r 会 exit 1),
    # 绝不在未验证的情况下执行 sysupgrade。
    SIGN_PUB="/etc/firmware-signing.pub"
    SIDECAR="${REMOTE_FIRMWARE}.sha256"
    [ -x /usr/bin/openssl ] || TIME r "缺少 /usr/bin/openssl, 无法校验固件签名, 已中止升级"
    [ -f "$SIGN_PUB" ] || TIME r "缺少固件签名公钥 ${SIGN_PUB}, 已中止升级"
    rm -f "$DOWNLOAD_PATH/$SIDECAR" "$DOWNLOAD_PATH/$SIDECAR.sig"
    # 2026-10-23: RELEASE_DOWNLOAD1="${GITHUB_PROXY}/${RELEASE_DOWNLOAD}" 在 proxy 为空时
    # 会拼成 "/https://..." 这种畸形地址, 每轮白等一次超时; 这里只在 proxy 非空时才用。
    # 另外补 --no-check-certificate: 主固件下载就是这么取的, 设备缺 CA 时不能让清单先挂掉。
    SIGN_BASES="$RELEASE_DOWNLOAD2"
    [ -n "$GITHUB_PROXY" ] && SIGN_BASES="$GITHUB_PROXY/$RELEASE_DOWNLOAD $SIGN_BASES"
    for base in $SIGN_BASES; do
        [ -n "$base" ] || continue
        # 2026-10-24: wget 优先。设备实测 uclient-fetch 打 GitHub release 直链一律
        # "Connection timed out"(rc=4), 而 wget-ssl 正常, 且它是本包的直接依赖。
        wget -q --no-check-certificate --timeout=60 -t 1 "$base/$SIDECAR" -O "$DOWNLOAD_PATH/$SIDECAR" 2>/dev/null \
          || uclient-fetch -q --timeout=60 --no-check-certificate "$base/$SIDECAR" -O "$DOWNLOAD_PATH/$SIDECAR" 2>/dev/null \
          || continue
        wget -q --no-check-certificate --timeout=60 -t 1 "$base/$SIDECAR.sig" -O "$DOWNLOAD_PATH/$SIDECAR.sig" 2>/dev/null \
          || uclient-fetch -q --timeout=60 --no-check-certificate "$base/$SIDECAR.sig" -O "$DOWNLOAD_PATH/$SIDECAR.sig" 2>/dev/null \
          || continue
        [ -s "$DOWNLOAD_PATH/$SIDECAR" ] && [ -s "$DOWNLOAD_PATH/$SIDECAR.sig" ] && break
    done
    if [ ! -s "$DOWNLOAD_PATH/$SIDECAR" ] || [ ! -s "$DOWNLOAD_PATH/$SIDECAR.sig" ]; then
        TIME r "未取得 ${SIDECAR} 或其签名, 该发布未签名, 已中止升级"
    fi
    if ! /usr/bin/openssl pkeyutl -verify -pubin -inkey "$SIGN_PUB" -rawin \
        -in "$DOWNLOAD_PATH/$SIDECAR" -sigfile "$DOWNLOAD_PATH/$SIDECAR.sig" >/dev/null 2>&1; then
        TIME r "固件签名校验失败, 已中止升级"
    fi
    # 2026-10-22: $REMOTE_FIRMWARE 来自未认证的 zzz_api(上游用 --no-check-certificate 取的),
    # 早先写成 awk '$2 == "'"$REMOTE_FIRMWARE"'" ...' 会被资产名里的引号闭合字符串、把
    # 剩余部分当 awk 程序执行(MITM 可 root RCE)。改成 -v 传值 + 字符白名单, 双保险。
    case "$REMOTE_FIRMWARE" in
        *[!A-Za-z0-9._+-]*) TIME r "云端固件名含非法字符, 已中止升级" ;;
        "") TIME r "云端固件名为空, 已中止升级" ;;
    esac
    EXPECT_SHA=$(awk -v rf="$REMOTE_FIRMWARE" '$2 == rf { print $1; exit }' "$DOWNLOAD_PATH/$SIDECAR")
    [ -n "$EXPECT_SHA" ] || TIME r "签名清单中没有 ${REMOTE_FIRMWARE} 的 SHA256 记录, 已中止升级"
    if [ "$EXPECT_SHA" != "$(sha256sum "$DOWNLOAD_PATH/$REMOTE_FIRMWARE" | cut -d' ' -f1)" ]; then
        TIME r "固件 SHA256 与签名清单不一致, 已中止升级"
    fi
    TIME g "固件签名与 SHA256 校验通过"
PW_SIGN_EOF
  awk -v blk="$PW_BLK" '!done && /^    # 移除 gzip 包$/ { while ((getline line < blk) > 0) print line; close(blk); done=1 } { print }' \
    "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"
  rm -f "$PW_BLK"
fi
grep -q '固件签名与 SHA256 校验通过' "$AU_BIN" || { echo "!! 升级验签补丁未插入 ${AU_BIN}"; exit 1; }
grep -q '/usr/bin/openssl pkeyutl -verify' "$AU_BIN" || { echo "!! 升级验签补丁内容不完整"; exit 1; }
echo "== luci-app-autoupdate 的 AutoUpdate 已补强制验签 =="

# 2026-10-22: 同一包里还有个 AutoUpgrade(13627 字节), 是更老的升级脚本副本:
# 一样 wget --no-check-certificate 下载, 但完全没有验签代码。现在它被"MD5 片段恒不等"
# 这个缺陷意外挡在 exit 1 上, 属"坏但安全" —— 一旦有人放宽那个校验, 它立刻变成
# 完整的不验签升级通道。LuCI 只调 AutoUpdate(-c/-u/-k), 没有任何代码调用 AutoUpgrade,
# 所以直接删掉, 不给它变成后门的机会。
AU_OLD="$AU_PKG/root/usr/bin/AutoUpgrade"
if [ -f "$AU_OLD" ]; then
  rm -f "$AU_OLD"
  echo "== 已移除无验签的 AutoUpgrade 副本 =="
fi
# 用 if 而不是 `[ -f ] && {...}`: 后者在文件已删除时会返回 1, 作为块内最后一条命令
# 会把整个 post-feeds 的退出码带成 1(实测模拟脚本 rc=1), 构建侧一检查就会误判失败。
if [ -f "$AU_OLD" ]; then
  echo "!! 无验签的 ${AU_OLD} 删除失败"
  exit 1
fi

# 2026-10-22: 原脚本在下载完成后会 `opkg remove gzip`(apk 系统是 `apk del`)再升级。
# 实测这台机器: /bin/gzip -> /usr/libexec/gzip-gnu, busybox 没有 gzip applet, 而 busybox tar
# 的 -z 是"调用外部 gzip 二进制"实现的(`PATH=/nonexistent busybox tar -czf x` →
# "tar: can't execute 'gzip'")。紧接着 `-u` 分支要 `sysupgrade -b /mnt/upback.tar.gz`, 那条
# 命令内部就是 `tar c${TAR_V}zf`, 备份失败后 sysupgrade 会 `rm -f $conf_tar; exit 1`, 于是
# `[ -f /mnt/upback.tar.gz ]` 为假 → 退化成 `sysupgrade -F -q`(不保留配置) → 升级完配置全丢。
# 镜像解压走 get_image 的 `busybox zcat`(这个 applet 在, 实测不需要外部 gzip), 所以整段删除。
GZIP_DEL_RE='(opkg +remove|apk +del(ete)?) +gzip'
if grep -qE "$GZIP_DEL_RE" "$AU_BIN"; then
	grep -q '^    # 移除 gzip 包$' "$AU_BIN" || {
		echo "!! 上游 gzip 删除段还在, 但注释锚点 '# 移除 gzip 包' 不见了, 无法安全定位删除范围"
		exit 1
	}
  perl -0pi -e 's{    # 移除 gzip 包\n.*?\n    fi\n}{    # 2026-10-22: 这里原本会 opkg/apk 删除 gzip。但 busybox tar -z 需要外部 gzip 二进制,\n    #   而下面的 sysupgrade -b 正是 tar czf —— 删掉 gzip 会让备份失败、退化成不保留配置升级。\n    #   镜像解压走 busybox zcat, 不需要这个包, 所以整段去掉。\n}s' "$AU_BIN"
fi
if grep -qE "$GZIP_DEL_RE" "$AU_BIN"; then echo "!! 移除 gzip 的代码段没删掉(上游改写?), -u 升级会丢配置"; exit 1; fi
echo "== 已去掉升级前删除 gzip 的逻辑(否则 -u 备份失败、配置会丢) =="
# 2026-10-28: 包内脚本的 -u 分支(就是 LuCI 一键升级和 cron 走的那条)有三个问题,
#   之前只顺手删了它的 gzip 段, 这三处一直没管:
#   1) 打包前 `mv /etc/config/luci /tmp/beifen_luci` → 备份 tar 里没有 /etc/config/luci,
#      恢复后又立刻被 -f 顶替系统自动备份, 于是每次升级主题/语言/会话设置都回默认值;
#   2) 备份写到 /mnt, 而 /mnt 就在 overlay 上, 和被升级的系统同一块盘;
#   3) 每次升级都往 crontab 追加 `check_network`, 那个脚本在镜像里根本不存在,
#      留下只会每 10 分钟刷一条 sh: not found(post-feeds 删的是静态那行, 拦不住这里)。
#   正常路径去掉 -F, 先 sysupgrade -T 检查兼容性; -q 只是静默, -n 才是不保留配置。
if grep -q 'beifen_luci' "$AU_BIN"; then
  perl -0pi -e 's{        # 清理配置文件\n        mv /etc/config/luci /tmp/beifen_luci\n        # 添加定时任务\n        sed -i .*?check_network.*?\n        echo .*?check_network.*?\n        # 重启 cron 服务\n        /etc/init.d/cron restart\n        # 备份系统\n        rm -rf /mnt/\*upback\.tar\.gz\n        sysupgrade -b /mnt/upback\.tar\.gz\n        mv /tmp/beifen_luci /etc/config/luci\n}{        # 2026-10-28: 备份必须原样包含 /etc/config/luci, 且不能写在 overlay 上的 /mnt\n        #   (细节见 post-feeds.sh 里同名注释); check_network 的定时任务也不再追加。\n        rm -f /tmp/upback.tar.gz\n        ( umask 077; sysupgrade -b /tmp/upback.tar.gz )\n        chmod 600 /tmp/upback.tar.gz 2>/dev/null || true\n}s' "$AU_BIN"
  perl -0pi -e 's{if \[ -f "/mnt/upback\.tar\.gz" \]; then}{if [ -f "/tmp/upback.tar.gz" ]; then}; s{UPGRADE_COMMAND="sysupgrade -F -f /mnt/upback\.tar\.gz"}{UPGRADE_COMMAND="sysupgrade -f /tmp/upback.tar.gz"}; s{UPGRADE_COMMAND="sysupgrade -F -q"}{UPGRADE_COMMAND="sysupgrade"}; s{UPGRADE_COMMAND="sysupgrade -F -n"}{UPGRADE_COMMAND="sysupgrade -n"}' "$AU_BIN"
  # 2026-10-31: sysupgrade -b 失败时可能留下 0 字节文件, [ -f ] 仍为真, 于是这里会用
  # -f 刷入一个损坏备份(配置全丢)。改成 [ -s ]: 空文件按失败处理, 退回 sysupgrade。
  perl -0pi -e 's{if \[ -f "/tmp/upback\.tar\.gz" \]; then}{if [ -s "/tmp/upback.tar.gz" ]; then}' "$AU_BIN"
  # 2026-10-30: 正常升级不再用 -F。先 sysupgrade -T 验证镜像与当前设备/分区兼容,
  # 失败就中止; 确认要强制刷机时由用户手动执行 -F, 不让 OTA 静默绕过检查。
  if ! grep -q 'sysupgrade -T' "$AU_BIN"; then
    grep -q '^    \$UPGRADE_COMMAND "\$DOWNLOAD_PATH/\$REMOTE_FIRMWARE"$' "$AU_BIN" || {
      echo "!! 包内 AutoUpdate 缺少 UPGRADE_COMMAND 执行行, 无法插入 -T 检查"; exit 1
    }
    awk '!done && /^    \$UPGRADE_COMMAND "\$DOWNLOAD_PATH\/\$REMOTE_FIRMWARE"$/ {
      print "    if ! sysupgrade -T \"$DOWNLOAD_PATH/$REMOTE_FIRMWARE\"; then"
      print "        TIME r \"镜像兼容性检查失败(sysupgrade -T), 已中止; 如确认强制刷机请手动执行 sysupgrade -F\""
      print "    fi"
      print
      done=1
      next
    }
    { print }' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"
  fi
fi
if grep -q 'UPGRADE_COMMAND="sysupgrade -F' "$AU_BIN"; then
  echo "!! 包内 AutoUpdate 正常升级仍使用 sysupgrade -F"
  exit 1
fi
grep -q 'sysupgrade -T' "$AU_BIN" || { echo "!! 包内 AutoUpdate 没有 sysupgrade -T 兼容性检查"; exit 1; }
if grep -q 'beifen_luci' "$AU_BIN"; then
  echo "!! 包内 AutoUpdate 的 luci 搬移段没删掉(上游改写?), 升级会丢 LuCI 配置"
  exit 1
fi
if grep -q "/mnt/upback" "$AU_BIN"; then
  echo "!! 包内 AutoUpdate 的备份仍写在 /mnt(overlay 上)"
  exit 1
fi
grep -q '\[ -s "/tmp/upback.tar.gz" \]' "$AU_BIN" || {
  echo "!! 包内 AutoUpdate 的备份判定没有改成非空检查(0 字节备份仍会被 -f 刷入)"; exit 1
}
if grep -q 'usr/bin/check_network' "$AU_BIN"; then
  echo "!! 包内 AutoUpdate 仍会往 crontab 追加 check_network"
  exit 1
fi
echo "== 已修正包内 AutoUpdate 的 -u 备份路径/配置搬移/check_network 追加 =="

# 2026-10-29: REMOTE_FIRMWARE 来自未认证的 zzz_api；原来只在下载和 chmod 之后才
# 做字符白名单。现在把校验前移到 Remote_download 的第一行，任何 rm/wget/chmod
# 之前就拒绝非法名字，避免路径注入。
if ! grep -q '2026-10-29: 下载前校验固件名' "$AU_BIN"; then
  grep -q '^Remote_download() {$' "$AU_BIN" || {
    echo "!! 包内 AutoUpdate 缺少 Remote_download 锚点, 无法插入下载前固件名校验"; exit 1
  }
  awk '!done && /^Remote_download\(\) \{$/ {
    print
    print "    # 2026-10-29: 下载前校验固件名, 拒绝未认证 API 注入的路径字符"
    print "    case \"$REMOTE_FIRMWARE\" in"
    print "        *[!A-Za-z0-9._+-]*|\"\") TIME r \"云端固件名含非法字符, 已中止升级\" ;;"
    print "    esac"
    print ""
    done=1
    next
  }
  { print }' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"
fi
grep -q '2026-10-29: 下载前校验固件名' "$AU_BIN" || {
  echo "!! 包内 AutoUpdate 的下载前固件名校验未插入"; exit 1
}
echo "== 包内 AutoUpdate 已在下载前校验 REMOTE_FIRMWARE =="

# 2026-10-29: 包内空间检查的两个字段可能为空(jq 失败/df 失败), 空值交给 [ ] 会报整数错误。
# 这里给 defaults 0, 让后续检查 fail-closed 并给出明确提示; 同时把相对 tmp 路径改成绝对路径。
if ! grep -q '2026-10-29: 下载前数值校验' "$AU_BIN"; then
  grep -q 'SIZE=$(jq -r --arg rd "$RELEASE_DOWNLOAD"' "$AU_BIN" || {
    echo "!! 包内 AutoUpdate 找不到 SIZE 赋值, 无法插入数值校验"; exit 1
  }
  awk '!done && /^        SIZE=\$\(jq -r --arg rd/ {
    print
    print "        # 2026-10-29: 下载前数值校验, jq 失败/字段缺失时不要把空值传给 bc"
    print "        case \"${SIZE:-}\" in"
    print "            \"\"|*[!0-9]*) SIZE=0 ;;"
    print "        esac"
    done=1
    next
  }
  { print }' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"

  awk '!done && /^    TMP_AVAILABLE=\$\(df -m/ {
    print
    print "    # 2026-10-29: 下载前数值校验, df 失败时不要把空值传给 test"
    print "    case \"${TMP_AVAILABLE:-}\" in"
    print "        \"\"|*[!0-9]*) TMP_AVAILABLE=0 ;;"
    print "    esac"
    done=1
    next
  }
  { print }' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"

  sed -i 's#rm -rf tmp/\*_version#rm -rf /tmp/*_version#; s#rm -rf "tmp/tags_version"#rm -rf "/tmp/tags_version"#' "$AU_BIN"
fi
grep -q '2026-10-29: 下载前数值校验' "$AU_BIN" || {
  echo "!! 包内 AutoUpdate 的数值校验未插入"; exit 1
}
grep -q 'rm -rf /tmp/\*_version' "$AU_BIN" || {
  echo "!! 包内 AutoUpdate 的临时路径仍是相对路径"; exit 1
}
echo "== 包内 AutoUpdate 已补空间字段校验和绝对 tmp 路径 =="

# 2026-10-28: 包内脚本挑云端固件是 `grep -E "$regex" "$tmpapi_version" | tail -n 1`,
#   同样依赖 GitHub 按上传顺序返回资产。手工补传一个旧版本做回滚时, 它会被选中,
#   设备拿旧版本比较 → 走 -lt 分支 → cron 无人值守时 read 读到空输入直接 exit 0,
#   自动更新从此静默停摆且不报错。改成先把固件名抽出来再排序取最大。
# 2026-10-31(O9): 不能按整串字典序(前缀/启动类型/哈希都会参与比较)。抽出 12 位
#   时间戳做数值排序; 没有时间戳时才退回字典序。兼容已经打过旧 patch 的缓存。
# 2026-10-29: 只锚定 target_line= 这一行, 不再替换全文件所有 `| tail -n 1)`。
#   旧写法在上游出现第二处 `| tail -n 1)` 时会把无关代码改坏, 而 sh -n 抓不到。
TARGET_ORIG='    target_line=$(grep -E "$regex" "$tmpapi_version" | tail -n 1)'
TARGET_OLD_PATCH='    target_line=$(grep -E "$regex" "$tmpapi_version" | grep -Eo "${LUCI_EDITION}-${SOURCE}-${DEVICE_MODEL}-[0-9]+-${BOOT_TYPE}-.*${FIRMWARE_SUFFIX}" | sort | tail -n 1)'
TARGET_PATCH="$(cat <<'TARGET_PATCH_EOF'
    target_line=$(grep -E "$regex" "$tmpapi_version" | grep -Eo "${LUCI_EDITION}-${SOURCE}-${DEVICE_MODEL}-[0-9]+-${BOOT_TYPE}-.*${FIRMWARE_SUFFIX}" | awk -F- '{for(i=1;i<=NF;i++){if(length($i)==12 && $i ~ /^[0-9]+$/){print $i " " $0; break}}}' | sort -n | tail -n 1 | cut -d' ' -f2-)
TARGET_PATCH_EOF
)"
ORIG_COUNT="$(grep -Fxc "$TARGET_ORIG" "$AU_BIN" || true)"
OLD_COUNT="$(grep -Fxc "$TARGET_OLD_PATCH" "$AU_BIN" || true)"
if [ "${ORIG_COUNT}" -gt 1 ] || [ "${OLD_COUNT}" -gt 1 ] || \
   { [ "${ORIG_COUNT}" -eq 1 ] && [ "${OLD_COUNT}" -eq 1 ]; }; then
  echo "!! 包内 AutoUpdate 的 target_line 锚点不唯一(orig=${ORIG_COUNT}, old=${OLD_COUNT})"
  exit 1
fi
if [ "${ORIG_COUNT}" -eq 1 ]; then
  awk -v orig="$TARGET_ORIG" -v patched="$TARGET_PATCH" '
    !done && $0 == orig { print patched; done=1; next }
    { print }
  ' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"
elif [ "${OLD_COUNT}" -eq 1 ]; then
  awk -v orig="$TARGET_OLD_PATCH" -v patched="$TARGET_PATCH" '
    !done && $0 == orig { print patched; done=1; next }
    { print }
  ' "$AU_BIN" > "$AU_BIN.new" && mv "$AU_BIN.new" "$AU_BIN"
fi
PATCHED_COUNT="$(grep -Fxc "$TARGET_PATCH" "$AU_BIN" || true)"
[ "${PATCHED_COUNT}" -eq 1 ] || {
  echo "!! 包内 AutoUpdate 未按时间戳数值取最大(上游改写? target_line 锚点没命中)"
  exit 1
}
echo "== 包内 AutoUpdate 改为按时间戳数值取最大, 不再依赖资产返回顺序 =="

# 2026-10-29: 删除原来的“Remote_download 版本守卫”。钉住的 04f2a37 里
# Remote_information 对 LOCAL == / > CLOUD 已调用 TIME z(exit 0), -u/-k 根本
# 到不了 Remote_download；插在 Remote_download 开头的 CLOUD_VERSION -lt LOCAL_VERSION
# 是永远不成立的死代码。注释里“-u 仍会下载导致降级”与上游不符。


# 2026-10-22: 同一个 `-u` 分支还会往 crontab 里塞 `*/10 * * * * /usr/bin/check_network`,
# 但镜像里没有这个文件(设备实测 ls: No such file or directory), 升级后 cron 每 10 分钟
# 报一次 exit 127。上游 AutoBuild 自带 check_network, 我们没有, 所以这段一起去掉。
if grep -q 'usr/bin/check_network' "$AU_BIN"; then
  perl -0pi -e 's{        # 添加定时任务\n.*?\n        /etc/init.d/cron restart\n}{        # 2026-10-22: 原本这里写 */10 的 check_network 定时任务, 但镜像里没有这个脚本,\n        #   升级后 cron 只会每 10 分钟刷一条 exit 127, 已去掉。\n}s' "$AU_BIN"
fi
if grep -q 'usr/bin/check_network' "$AU_BIN"; then echo "!! check_network 定时任务没删掉(上游改写?)"; exit 1; fi
echo "== 已去掉指向不存在脚本的 check_network 定时任务 =="

# 2026-10-24: 代理地址为空时别拼出畸形 URL。
# 上游: RELEASE_DOWNLOAD1="${GITHUB_PROXY}/${RELEASE_DOWNLOAD}" —— GITHUB_PROXY 为空时得到
# "/https://github.com/..."(前面多一个斜杠), uclient-fetch 报 "Failed to allocate uclient context"
# 再回落到 RELEASE_DOWNLOAD2 才成功。设备日志里每次 -c 都有这么一段红字, 纯噪音。
if ! grep -q 'RELEASE_DOWNLOAD1="${GITHUB_PROXY:+' "$AU_BIN"; then
  sed -i 's|^        RELEASE_DOWNLOAD1="${GITHUB_PROXY}/${RELEASE_DOWNLOAD}"$|        # 2026-10-24: 代理为空时不拼前导斜杠(否则每次 -c 都先报一次 URL 畸形)\n        RELEASE_DOWNLOAD1="${GITHUB_PROXY:+${GITHUB_PROXY}/}${RELEASE_DOWNLOAD}"|' "$AU_BIN"
fi
grep -q 'RELEASE_DOWNLOAD1="${GITHUB_PROXY:+' "$AU_BIN" || { echo "!! RELEASE_DOWNLOAD1 前导斜杠没去掉(上游脚本改了?)"; exit 1; }

# 2026-10-24: 下载器主备对调。设备实测(GitHub release 直链, 连续 4 次):
#   uclient-fetch --no-check-certificate -O f "$URL"  → rc=4, Connection timed out, 文件不生成
#   wget -q --no-check-certificate -O g "$URL"        → rc=0, 122 字节
# 而 wget-ssl 是 luci-app-autoupdate 的直接依赖(opkg whatdepends wget-ssl 可见), 必然在镜像里。
# 上游那两处 zzz_api 偏偏是 uclient 优先、wget 兜底 → 每次 -c/-u 先白等一个 40s 超时。
# 固件本体那段本来就是 wget 优先, 不动。这里只把 zzz_api 的主备对调。
if ! grep -q 'zzz_api 主备对调' "$AU_BIN"; then
  # 注意: perl 替换串里的 $ 必须写成 \$ —— 否则被 perl 当变量插值, 会替换成空字符串
  # (第一版就踩了这个坑: 打出来的脚本变成 `wget ... "/zzz_api" -O ""`, 差点静默废掉下载)。
  perl -0pi -e 's{if ! uclient-fetch --no-check-certificate --timeout=40 "\$RELEASE_DOWNLOAD1/zzz_api" -O "\$tmpapi_version"; then}{# 2026-10-24: zzz_api 主备对调(uclient-fetch 打 GitHub 直链会超时, wget 正常)\n                if ! wget -q --no-check-certificate --no-use-server-timestamps --timeout=40 -t 1 "\$RELEASE_DOWNLOAD1/zzz_api" -O "\$tmpapi_version"; then}g' "$AU_BIN"
  perl -0pi -e 's{wget -q --show-progress --no-check-certificate --no-use-server-timestamps --timeout=40 -t 1 "\$RELEASE_DOWNLOAD2/zzz_api" -O "\$tmpapi_version"}{uclient-fetch --no-check-certificate --timeout=40 "\$RELEASE_DOWNLOAD2/zzz_api" -O "\$tmpapi_version"}g' "$AU_BIN"
fi
grep -q 'zzz_api 主备对调' "$AU_BIN" || { echo "!! zzz_api 主备对调没打上(上游脚本改了?)"; exit 1; }
# 断言替换后变量没被吃掉(踩过: perl 插值把 \$RELEASE_DOWNLOAD1 变成空串)
grep -q 'wget -q --no-check-certificate --no-use-server-timestamps --timeout=40 -t 1 "\$RELEASE_DOWNLOAD1/zzz_api" -O "\$tmpapi_version"' "$AU_BIN" \
  || { echo "!! zzz_api 主备对调后变量被吞(perl 插值?), 下载地址会变成 /zzz_api"; exit 1; }
echo "== zzz_api 下载改为 wget 优先 =="

# 2026-10-24: 上面几处补丁都用 `> "$AU_BIN.new" && mv` 写过文件, 新文件按 umask 建出来是
# 0644 —— opkg 照 644 装进镜像, 结果 /usr/bin/AutoUpdate 不可执行(LuCI 直接 exec 它),
# 自动更新整条链路废掉。设备实测: -rw-r--r-- root root 15925 /usr/bin/AutoUpdate,
# `AutoUpdate -c` → "Permission denied"。这里补回 755 并断言可执行。
chmod 755 "$AU_BIN"
[ -x "$AU_BIN" ] || { echo "!! ${AU_BIN} 没有可执行位, 自动更新会 Permission denied"; exit 1; }
# 2026-10-24: 上面几个 perl -0pi 都是跨行非贪婪替换, 上游改缩进/结构时可能只替换一半。
# 只 grep 标记挡不住"半改但标记已被一并删掉"的情况, 这里补一道语法检查兜底。
sh -n "$AU_BIN" || { echo "!! ${AU_BIN} 打补丁后语法错误(perl 跨行替换只改了半截?)"; exit 1; }
echo "== AutoUpdate 权限已确保 755, 语法检查通过 =="

# 2026-10-22: LuCI 页面"本地版本"显示成字面量 ${CURRENT_Version}。
# 我们把 /etc/openwrt_update 写成了 shell 派生写法(LuCI_EDITION="${LUCI_Name}" 之类),
# AutoUpdate 是 `. /etc/openwrt_update` 求值, 没问题; 但 cbi 模型用 awk 抠字面量,
# 拿到的是 ${CURRENT_Version} 这个字符串本身。改成 source 求值。
AU_MODEL="$AU_PKG/luasrc/model/cbi/autoupdate/autoupdate.lua"
if [ -f "$AU_MODEL" ] && grep -q 'info\.local_version.*safe_exec(\[\[awk' "$AU_MODEL"; then
  sed -i '/info\.local_version.*safe_exec(\[\[awk/s|.*|    info.local_version = safe_exec([[. /etc/openwrt_update 2>/dev/null; echo "$FIRMWARE_VERSION"]])|' "$AU_MODEL"
fi
if [ -f "$AU_MODEL" ]; then
  # 上游改了写法就只警告不中断(只影响这一个显示项, 不影响升级链路)
  if grep -q 'echo "$FIRMWARE_VERSION"' "$AU_MODEL"; then
    echo "== LuCI 本地版本改为 source 求值 =="
  elif grep -q 'info\.local_version.*awk' "$AU_MODEL"; then
    echo "!! LuCI 本地版本补丁未生效(上游改写了这一行?), 页面仍会显示 \${CURRENT_Version}"
  fi
fi
fi

# 2026-10-22: clash_meta 是入库的 7.8MB UPX 加壳二进制, 随固件以 root 执行(OpenClash 内核)。
# 仓库里此前没有任何地方校验它 —— 有提交权限的人换一个后门, diff 只显示"字节数没变",
# 加壳还让静态扫描失效。这里钉死 sha256: 要升级内核, 请连同这里的值一起改并说明来源。
# 2026-10-29: 来源/更新规则见 build/common/CLASH_META.md。
CLASH_SHA="459c92959289214a8f8d11abea02057382048bc1add8574f04f1223b6095802a"
CLASH_HIT=0
for f in build/Lede_source/files/etc/openclash/core/clash_meta \
         package/base-files/files/etc/openclash/core/clash_meta; do
  [ -f "$f" ] || continue
  CLASH_HIT=1
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$got" = "$CLASH_SHA" ] || { echo "!! ${f} 的 sha256 与仓库记录不符($got)"; exit 1; }
done
[ "$CLASH_HIT" -eq 1 ] || { echo "!! 找不到 clash_meta(OpenClash 内核), 无法校验来源"; exit 1; }
echo "== clash_meta sha256 校验通过 =="

echo "== post-feeds 修补完成 =="
