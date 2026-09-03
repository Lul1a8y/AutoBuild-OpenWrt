#!/bin/bash
# https://github.com/Lul1a8y/AutoBuild-OpenWrt
# diy-part.sh — 权威插件源 + AdGuard Home + MosDNS + 内核6.6 + 编译时间 + 网口修复
# 更新日期: 2026-09-03
# 修复: mosdns feeds冲突(删旧版5.3.4-1→剩5.3.4-5) + AGH禁用自启动 + 编译时间精确到时分
# 2026-09-03: 补拉 geo2txt — luci-app-mosdns v1.7.12 新依赖，kenzok8/small 漏同步，9/2 编译在此失败

# ===== 内核锁定 6.6 LTS =====
sed -i 's/KERNEL_PATCHVER:=6.12/KERNEL_PATCHVER:=6.6/g' target/linux/x86/Makefile

# ===== ttyd 终端需密码登录 =====
sed -i '7a uci set system.@system[0].ttylogin=1' package/lean/default-settings/files/zzz-default-settings

# ===== 添加权威插件源 =====
git clone https://github.com/kenzok8/openwrt-packages package/kenzok8
git clone https://github.com/kenzok8/small package/kenzok8-small

# ===== geo2txt 补拉：luci-app-mosdns ≥1.7.12 的新依赖（2026-09-03 修复）=====
# 根因: kenzok8/small 同步 luci-app-mosdns 时漏带上游 sbwml/luci-app-mosdns
#       仓库里的 geo2txt 兄弟包 → package/install 阶段报:
#       pkg_hash_check_unresolved: cannot find dependency geo2txt for luci-app-mosdns
# 方案: 从 sbwml 官方 v5 分支克隆后拷贝 geo2txt 目录（同 filetransfer 的 clone+cp 做法，
#       sparse-checkout 在 CI 不稳定不用）
git clone --depth 1 --single-branch -b v5 \
	https://github.com/sbwml/luci-app-mosdns.git /tmp/mosdns-upstream
cp -r /tmp/mosdns-upstream/geo2txt package/kenzok8-small/geo2txt
rm -rf /tmp/mosdns-upstream

# ===== 默认IP 192.168.50.2 =====
sed -i "s/192.168.1.1/192.168.50.2/g" package/base-files/files/bin/config_generate

# ===== 主机名 Openwrt =====
sed -i "s/hostname='LEDE'/hostname='Openwrt'/g" package/base-files/files/bin/config_generate

# ===== 删除 feeds 冲突包（用权威源/官方源替换）=====
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-adguardhome
rm -rf feeds/packages/net/mosdns
rm -rf package/kenzok8-small/luci-app-passwall2

# ===== 删除 kenzok8/small 里自带的 openclash/ssr-plus，用官方最新源替换 =====
rm -rf package/kenzok8-small/luci-app-openclash
rm -rf package/kenzok8-small/luci-app-ssr-plus

# kenzok8 的 argon 主题/配置与 feeds/luci 冲突，且依赖不存在的 wget-any
# feeds/luci (coolsnowwolf) 已自带 argon，删除 kenzok8 版本避免递归依赖
rm -rf package/kenzok8/luci-theme-argon
rm -rf package/kenzok8/luci-app-argon-config

# ===== luci-mod-status 概览页说明 =====
# LEDE openwrt-25.12 的 luci-mod-status 用 ucode template (index.ut) + JS 视图
# .ut 优先级 > .htm，所以 autocore 的 index.htm 不会被 LuCI 使用
# autocore index.htm 依赖 luci.tools.status（openwrt-25.12 已删除此模块）
# 删 index.ut 会导致 LuCI 回退到 .htm → 报错，所以不要删 index.ut
# 自定义概览页内容通过修改 JS 视图实现（在工作流 yml 中处理）

# ===== 官方源 clone =====
git clone -b master https://github.com/vernesong/OpenClash.git package/openclash
git clone -b master https://github.com/fw876/helloworld.git package/helloworld

# ===== kenzok8/openwrt-packages 嵌套目录修复 =====
# kenzok8 仓库有些包存在 pkg/pkg/Makefile 嵌套，编译系统会跳过
for dir in package/kenzok8/*/; do
    base=$(basename "$dir")
    if [ -d "$dir/$base" ] && [ -f "$dir/$base/Makefile" ]; then
        mv "$dir/$base"/* "$dir/" 2>/dev/null
        rm -rf "$dir/$base"
    fi
done

# ===== AdGuard Home：删核心只留 LuCI 壳子 =====
# Lullaby 决定不预装 AGH 核心，只保留 luci-app 前端，之后自己下载配置
# 原因：AGH 核心随开机自启动（postinst enable + S95AdGuardHome），
# 没有 yaml 配置 → 走 web 向导 → 53 端口跟 dnsmasq 冲突 → DNS 异常
# uci-defaults 方案不可靠（postinst 在安装时就 enable 了，比 uci-defaults 早）

# 1. 删除 AGH 核心包源码（不编译核心二进制）
rm -rf package/kenzok8/adguardhome

# 2. 删除 luci-app-adguardhome 自带的预置 yaml
rm -f package/kenzok8/luci-app-adguardhome/root/etc/AdGuardHome.yaml

# 3. 修改 luci-app Makefile：
#    - 删掉 postinst 里的 enable（自启动根因）
#    - INCLUDE_binary 默认 y→n（不默认打包核心）
#    - 删掉 LUCI_DEPENDS 里的核心依赖声明
AGH_LUCI_MK="$(find package/kenzok8 -path '*/luci-app-adguardhome/Makefile' -print -quit 2>/dev/null)"
if [ -n "$AGH_LUCI_MK" ] && [ -f "$AGH_LUCI_MK" ]; then
	sed -i '/define Package\/luci-app-adguardhome\/postinst/,/^endef$/d' "$AGH_LUCI_MK"
	sed -i 's/default y/default n/' "$AGH_LUCI_MK"
	sed -i '/INCLUDE_binary:adguardhome/d' "$AGH_LUCI_MK"
fi
# 4. 修复 update_core.sh 架构映射：opkg 返回 "x86_64"，但脚本只匹配了 "x86"
# 原脚本 detect_arch() 里 case "$Archt" 只有 x86) 没有 x86_64)
# sed: 在 x86) 行前面插入 x86_64) Arch="amd64" ;;
AGH_UPDATE="$(find package/kenzok8 -path '*/AdGuardHome/update_core.sh' -print -quit 2>/dev/null)"
if [ -n "$AGH_UPDATE" ] && [ -f "$AGH_UPDATE" ]; then
	# 把 detect_arch() 里的 x86) 改成 x86_64|x86) ，同时匹配两种架构名
	sed -E -i 's/^([[:space:]]*)x86\)$/\1x86_64|x86)/' "$AGH_UPDATE"
fi

# ===== MosDNS v5 依赖保障 =====
# kenzok8/small 的 luci-app-mosdns 现为 v1.7.12（2026-09 实测），依赖：
# +mosdns +uclient-fetch +v2ray-geoip +v2ray-geosite +geo2txt +ucode
# mosdns/v2ray-geoip/v2ray-geosite 在 package/kenzok8-small/ 内自带
# geo2txt 由本文件上方从 sbwml/luci-app-mosdns(v5) 补拉
# .config 已显式声明这些运行时依赖
# 注意：不能在这里替换 feeds/packages/lang/golang
# 因为第二次 feeds update -a 会重置该目录

# ===== 翻译微调 =====
sed -i 's/"管理权"/"改密码"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po

# ===== 菜单归类调整 =====

# --- 访问控制 → 系统/管控 菜单 ---
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/controller/mia.lua 2>/dev/null || true
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/view/mia/mia_status.htm 2>/dev/null || true
sed -i 's|admin/services|admin/control|g' feeds/luci/applications/luci-app-accesscontrol/root/usr/share/luci/menu.d/luci-app-accesscontrol.json 2>/dev/null || true

# --- OpenList → NAS 菜单 ---
sed -i 's|admin/services/openlist|admin/nas/openlist|g' feeds/luci/applications/luci-app-openlist/root/usr/share/luci/menu.d/luci-app-openlist.json 2>/dev/null || true

# --- 文件浏览器 → 服务菜单 (从 NAS 移过来) ---

# --- Wol → 网络菜单 ---
sed -i 's/services/network/g' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json 2>/dev/null || true

# --- nlbwmon → 网络菜单 ---
sed -i 's/services/network/g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json 2>/dev/null || true

# --- ttyd → 系统菜单 ---
sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json 2>/dev/null || true

# ===== GFW 菜单归类 =====
# 修改 LuCI 内置 VPN 类别名称 → GFW
sed -i 's/"title": "VPN"/"title": "GFW"/g' feeds/luci/modules/luci-base/root/usr/share/luci/menu.d/luci-base.json 2>/dev/null || true
sed -i '/^msgid "VPN"$/,/^msgstr/s/^msgstr "VPN"/msgstr "GFW"/' feeds/luci/modules/luci-base/po/zh_Hans/base.po 2>/dev/null || true

# ⚠️ 顺序：先插入 GFW 父类别 entry，再做 services→vpn 替换
# 如果反过来，entry 插入模式 `{"admin", "services"}` 就不存在了（已被改为 vpn）

# --- OpenClash → GFW 菜单 (vernesong 官方源) ---
OC_CTRL=$(find package/openclash -path '*/controller/openclash.lua' -print -quit 2>/dev/null)
if [ -n "$OC_CTRL" ] && [ -f "$OC_CTRL" ]; then
	# 先插入 GFW 父类别
	sed -i '/entry({"admin", "services"}/i\
entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$OC_CTRL"
	# 再做 services→vpn 替换
	find package/openclash -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
		-exec sed -i 's/services/vpn/g' {} +
fi

# --- PassWall → GFW 菜单 (kenzok8/small) ---
PW_CTRL=$(find package/kenzok8-small -path '*/controller/passwall.lua' -print -quit 2>/dev/null)
if [ -n "$PW_CTRL" ] && [ -f "$PW_CTRL" ]; then
	# 先插入 GFW 父类别
	sed -i '/entry({"admin", "services"}/i\
entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$PW_CTRL"
	# 再做 services→vpn 替换（覆盖 api.lua 的 string.format 等所有路径引用）
	find package/kenzok8-small/luci-app-passwall -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
		-exec sed -i 's/services/vpn/g' {} +
fi

# --- SSR-Plus → GFW 菜单 (fw876/helloworld) ---
SSR_CTRL=$(find package/helloworld -path '*/controller/shadowsocksr.lua' -print -quit 2>/dev/null)
if [ -n "$SSR_CTRL" ] && [ -f "$SSR_CTRL" ]; then
	# 先插入 GFW 父类别
	sed -i '/entry({"admin", "services"}/i\
entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$SSR_CTRL"
	# 再做 services→vpn 替换（覆盖 url 函数和 build_url 调用）
	find package/helloworld/luci-app-ssr-plus -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
		-exec sed -i 's/services/vpn/g' {} +
fi

# --- MosDNS → GFW 菜单 (kenzok8/small, JS-based, 使用 menu.d JSON) ---
sed -i 's|admin/services/mosdns|admin/vpn/mosdns|g' package/kenzok8-small/luci-app-mosdns/root/usr/share/luci/menu.d/luci-app-mosdns.json 2>/dev/null || true

# --- ZeroTier & IPSec → LEDE feeds openwrt-25.12 已在 admin/vpn/，无需修改 ---

# ===== AdGuard Home 只留 LuCI 壳子，核心已删除 =====

# ===== 权限修复 =====
chmod -R 755 package/kenzok8 package/kenzok8-small package/openclash package/helloworld feeds/luci/applications/luci-app-filetransfer feeds/luci/libs/luci-lib-fs

# ===== MosDNS 版本修复 + 启动优化 =====
# 根因：feeds/packages/net/mosdns (coolsnowwolf) 是 5.3.4-1
# kenzok8/small 是 5.3.4-5，feeds install 优先用先声明的源 → 选中旧版 -1
# 已在上方 rm -rf feeds/packages/net/mosdns 删除旧版，只剩 kenzok8/small 的 5.3.4-5
# 不再需要版本锁定 sed
# mosdns init START=75 在 x86 设备上启动太早导致 DNS 重定向失败
# 降低启动优先级: START=75 → START=99，确保网络就绪后再启动
# 参考: https://github.com/sbwml/luci-app-mosdns/issues/253
MOSDNS_INIT="$(find package/kenzok8-small -path '*/init.d/mosdns' -print -quit 2>/dev/null)"
if [ -n "$MOSDNS_INIT" ] && [ -f "$MOSDNS_INIT" ]; then
	sed -i 's/^START=75$/START=99/' "$MOSDNS_INIT"
	# 确保默认配置文件路径为 /var/etc/mosdns.json（UCI 自动生成模式）
	sed -i 's|^CONF=.*|CONF="/var/etc/mosdns.json"|' "$MOSDNS_INIT"
fi

# ===== 概览页修复：board.json 定义网络拓扑 =====
# LEDE openwrt-25.12 用 DSA 模式，br-lan 端口由 board.json 定义
# 没有 board.json → config_generate 只把 eth0 加入 br-lan
# 有 board.json → 系统根据 network.ports 自动配置 br-lan 包含的所有端口
# J4125: 4x i225-V 2.5G, eth0/eth2/eth3 = LAN, eth1 = WAN
mkdir -p target/linux/x86/base-files/etc
cat > target/linux/x86/base-files/etc/board.json << 'BJEOF'
{
  "model": {
    "id": "x86-64",
    "name": "J4125 x86_64 Router"
  },
  "network": {
    "lan": {
      "protocol": "static",
      "ports": [
        "eth0",
        "eth2",
        "eth3"
      ]
    },
    "wan": {
      "protocol": "dhcp",
      "ports": [
        "eth1"
      ]
    }
  }
}
BJEOF

# ===== x86 generic 板型网口注册 =====
# ⚠️ 已删除：02_network sed 注入和 network config sed
# 根因：sed 的 \n 转义在 dash/sh 下不生效为换行，导致 02_network 脚本语法错误
#       → board.d 执行失败 → 网络配置生成异常 → kmodloader 卡住
# board.json 已定义 network.ports，config_generate 会读取并配置 br-lan
# 不需要额外修改 02_network 和 /etc/config/network

# ===== 固件编译日期（精确到时分）=====
# openwrt-25.12 概览页用 JS 视图（index.ut + 10_system.js）
# 编译时间通过 yml 工作流中的 sed 插入 10_system.js 实现
# yml 中 Compile_Date 环境变量已在 "加载设置" 步骤设置
# 不需要在此脚本中设置 COMPILE_TIME

# ===== 修复 luci-theme-argon 依赖 =====
sed -i 's/+@wget-any //g' feeds/luci/themes/luci-theme-argon/Makefile 2>/dev/null || true

# --- 系统菜单→文件传输（上传+安装ipk）---
# luci-app-filetransfer 在 coolsnowwolf/luci master 分支，openwrt-25.12 已移除
# ⚠️ 必须同时获取 luci-lib-fs（filetransfer 的依赖），否则编译缺少依赖被跳过
# ⚠️ 必须拷贝到 feeds/luci/applications/ 而非 package/，因为 Makefile 里的
# `include ../../luci.mk` 是相对 feeds/luci/applications/ 的路径
# ⚠️ 必须添加 menu.d JSON，LuCI 23.05+ 的菜单树从 menu.d 生成，缺了菜单不显示
# ⚠️ 必须添加 ACL 权限文件，否则 rpcd 不授权页面访问
# 不用 sparse-checkout（CI 环境经常失败），clone depth 1 后直接 cp
git clone --depth 1 --single-branch -b master \
	https://github.com/coolsnowwolf/luci.git /tmp/ft-luci
cp -r /tmp/ft-luci/applications/luci-app-filetransfer feeds/luci/applications/
cp -r /tmp/ft-luci/libs/luci-lib-fs feeds/luci/libs/
rm -rf /tmp/ft-luci

# 删除旧版 po/zh-cn（LuCI 23.05+ 用 po/zh_Hans，避免冲突）
rm -rf feeds/luci/applications/luci-app-filetransfer/po/zh-cn

# 添加 zh_Hans 翻译（旧 po 用 zh-cn，新 luci 用 zh_Hans）
mkdir -p feeds/luci/applications/luci-app-filetransfer/po/zh_Hans
cat > feeds/luci/applications/luci-app-filetransfer/po/zh_Hans/filetransfer.po << 'POEOF'
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
"Language: zh_Hans\n"

msgid "Choose local file:"
msgstr "选择本地文件："

msgid "Delete"
msgstr "删除"

msgid "Download"
msgstr "下载"

msgid "FileTransfer"
msgstr "文件传输"

msgid "Install"
msgstr "安装"

msgid "Install ipk file ?"
msgstr "安装 ipk 文件？"

msgid "Submit"
msgstr "提交"

msgid "Upload"
msgstr "上传"

msgid "Upload and Install ipk File"
msgstr "上传并安装 ipk 文件"

msgid "Upload File"
msgstr "上传文件"

msgid "Upload log"
msgstr "上传日志"

msgid "Uploaded Files"
msgstr "已上传的文件"
POEOF

# --- 添加 menu.d JSON（LuCI 23.05+ 菜单树依赖 menu.d，缺了菜单不显示）---
mkdir -p feeds/luci/applications/luci-app-filetransfer/root/usr/share/luci/menu.d
cat > feeds/luci/applications/luci-app-filetransfer/root/usr/share/luci/menu.d/luci-app-filetransfer.json << 'MDEOF'
{
	"admin/system/filetransfer": {
		"title": "FileTransfer",
		"order": 89,
		"action": {
			"type": "view",
			"path": "filetransfer"
		},
		"depends": {
			"acl": [
				"luci-app-filetransfer"
			]
		}
	}
}
MDEOF

# --- 添加 ACL 权限文件（rpcd 需要授权才能访问页面）---
mkdir -p feeds/luci/applications/luci-app-filetransfer/root/usr/share/rpcd/acl.d
cat > feeds/luci/applications/luci-app-filetransfer/root/usr/share/rpcd/acl.d/luci-app-filetransfer.json << 'ACLEOF'
{
	"luci-app-filetransfer": {
		"description": "Grant access to FileTransfer",
		"read": {
			"ubus": {
				"file": [
					"list",
					"read",
					"stat"
				]
			}
		},
		"write": {
			"cgi-io": [
				"upload",
				"download"
			],
			"ubus": {
				"file": [
					"list",
					"read",
					"write",
					"remove",
					"exec"
				]
			},
			"file": {
				"/tmp/upload": [
					"list",
					"read",
					"write"
				]
			}
		}
	}
}
ACLEOF

# --- UPnP 翻译 ---
sed -i 's/msgstr "UPnP"/msgstr "UPnP设置"/g' feeds/luci/applications/luci-app-upnp/po/zh_Hans/upnp.po 2>/dev/null || true
