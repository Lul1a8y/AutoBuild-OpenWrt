#!/bin/bash
# https://github.com/Lul1a8y/AutoBuild-OpenWrt
# diy-part.sh — 权威插件源 + AdGuard Home + MosDNS + 内核6.6
# 插件源分工:
# kenzok8/openwrt-packages → luci-app + 独立服务 (adguardhome, smartdns 等)
# kenzok8/small → 代理类 (passwall, mosdns) + 核心依赖 (sing-box, xray 等)
# vernesong/OpenClash → OpenClash 官方最新版
# fw876/helloworld → SSR-Plus 官方最新版

# ===== 内核锁定 6.6 LTS =====
sed -i 's/KERNEL_PATCHVER:=6.12/KERNEL_PATCHVER:=6.6/g' target/linux/x86/Makefile

# ===== 修改默认IP =====
sed -i "s/192.168.1.1/192.168.50.2/g" package/base-files/files/bin/config_generate

# ===== ttyd 终端需密码登录 =====
sed -i '7a uci set system.@system[0].ttylogin=1' package/lean/default-settings/files/zzz-default-settings

# ===== 添加权威插件源 =====
# kenzok8/openwrt-packages — luci应用 + 独立服务包 (含 AdGuard Home 核心及 luci)
git clone https://github.com/kenzok8/openwrt-packages package/kenzok8
# kenzok8/small — 代理类 + 核心依赖库
git clone https://github.com/kenzok8/small package/kenzok8-small

# ===== 删除 LEDE 自带的旧版代理插件，避免冲突 =====
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf package/kenzok8-small/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-ssr-plus
rm -rf feeds/luci/applications/luci-app-mosdns

# ===== 删除 kenzok8/small 里自带的 openclash/ssr-plus，用官方最新源替换 =====
rm -rf package/kenzok8-small/luci-app-openclash
rm -rf package/kenzok8-small/luci-app-ssr-plus

# OpenClash 官方源 (vernesong，持续更新)
git clone -b master https://github.com/vernesong/OpenClash.git package/openclash
# SSR-Plus 官方源 (fw876，持续更新)
git clone -b master https://github.com/fw876/helloworld package/helloworld

# ===== AdGuard Home =====
# adguardhome 核心包 → package/kenzok8/adguardhome
# luci-app-adguardhome → package/kenzok8/luci-app-adguardhome
# 依赖库由 kenzok8/small 提供

# ===== 删除 kenzok8 里与 LEDE feeds 冲突的包 =====
rm -rf package/kenzok8/luci-app-filebrowser

# ===== 修复 kenzok8 嵌套目录结构 =====
# kenzok8/openwrt-packages 的 partexp 等包有嵌套结构: pkg/pkg/Makefile
# OpenWrt 需要: pkg/Makefile，将内层移到外层
for _dir in package/kenzok8/*/; do
	_pkg=$(basename "$_dir")
	if [ -d "${_dir}${_pkg}" ] && [ -f "${_dir}${_pkg}/Makefile" ] && [ ! -f "${_dir}Makefile" ]; then
		mv "${_dir}${_pkg}"/* "${_dir}" 2>/dev/null
		rm -rf "${_dir}${_pkg}"
	fi
done

# ===== UI 汉化微调（保留原作者风格） =====
# 系统
sed -i 's/"管理权"/"改密码"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
# 文件管理器 → 文件传输
sed -i 's/msgstr "文件管理器"/msgstr "文件传输"/g' feeds/luci/applications/luci-app-filemanager/po/zh_Hans/filemanager.po 2>/dev/null || true

# 服务
sed -i 's/ShadowSocksR Plus+/SSR Plus+/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua 2>/dev/null || true
sed -i 's/msgstr "KMS 服务器"/msgstr "KMS 服务"/g' feeds/luci/applications/luci-app-vlmcsd/po/zh_Hans/vlmcsd.po 2>/dev/null || true
sed -i 's/msgstr "UPnP"/msgstr "UPnP设置"/g' feeds/luci/applications/luci-app-upnp/po/zh_Hans/upnp.po 2>/dev/null || true
# 管控
sed -i 's/"上网时间控制"/"上网控制"/g' feeds/luci/applications/luci-app-accesscontrol/po/zh-cn/mia.po 2>/dev/null || true
# 存储
sed -i 's/msgstr "OpenList"/msgstr "网盘挂载"/g' feeds/luci/applications/luci-app-openlist/po/zh_Hans/openlist.po 2>/dev/null || true
sed -i 's/msgstr "FileBrowser"/msgstr "文件管理"/g' feeds/luci/applications/luci-app-filebrowser/po/zh_Hans/filebrowser.po 2>/dev/null || true
sed -i 's/msgstr "FTP 服务器"/msgstr "FTP 服务"/g' feeds/luci/applications/luci-app-vsftpd/po/zh_Hans/vsftpd.po 2>/dev/null || true
sed -i 's/msgstr "qbittorrent"/msgstr "qb下载"/g' feeds/luci/applications/luci-app-qbittorrent/po/zh_Hans/qbittorrent.po 2>/dev/null || true
# GFW
sed -i 's/IPSec VPN 服务器/IPSec 服务/g' feeds/luci/applications/luci-app-ipsec-vpnd/po/zh_Hans/ipsec.po 2>/dev/null || true
# 网络
sed -i '18d' feeds/luci/applications/luci-app-arpbind/po/zh_Hans/arpbind.po 2>/dev/null || true
sed -i '17a msgstr "MAC绑定"' feeds/luci/applications/luci-app-arpbind/po/zh_Hans/arpbind.po 2>/dev/null || true
sed -i 's/msgstr "Socat"/msgstr "端口转发"/g' feeds/luci/applications/luci-app-socat/po/zh_Hans/socat.po 2>/dev/null || true
sed -i 's/Turbo ACC 网络加速/网络加速/g' feeds/luci/applications/luci-app-turboacc/po/zh-cn/turboacc.po 2>/dev/null || true
# 菜单重命名
sed -i 's/网络存储/存储/g' feeds/luci/applications/luci-app-vsftpd/po/zh_Hans/vsftpd.po 2>/dev/null || true
sed -i 's/带宽监控/统计/g' feeds/luci/applications/luci-app-nlbwmon/po/zh_Hans/nlbwmon.po 2>/dev/null || true

# ===== 欢迎页信息 =====
sed -i '63d' package/lean/autocore/files/x86/index.htm 2>/dev/null || true
sed -i '62a localtime = os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X"),' package/lean/autocore/files/x86/index.htm 2>/dev/null || true
sed -i '750a <tr><td width="33%"><%:固件编译日期%></td><td id="cpuusage">Lul1a8y 2026.05.04</td></tr>' package/lean/autocore/files/x86/index.htm 2>/dev/null || true
sed -i "s/2026.05.04/$(TZ=UTC-8 date \"+%Y.%m.%d\")/g" package/lean/autocore/files/x86/index.htm 2>/dev/null || true

# ===== 调整菜单归类 =====
# ttyd → LEDE feeds 已在 system 菜单，无需修改

# 上网时间控制 → 管控菜单 (旧版 Lua controller，新版可能用 JS，2>/dev/null 兜底)
sed -i 's|admin/services|admin/control|g' feeds/luci/applications/luci-app-accesscontrol/luasrc/controller/mia.lua 2>/dev/null || true
sed -i 's|admin/services|admin/control|g' feeds/luci/applications/luci-app-accesscontrol/luasrc/view/mia/mia_status.htm 2>/dev/null || true
sed -i 's|admin/services|admin/control|g' feeds/luci/applications/luci-app-accesscontrol/root/usr/share/luci/menu.d/luci-app-accesscontrol.json 2>/dev/null || true

# OpenList → NAS 菜单 (LEDE feeds 版本，原名 AList)
sed -i 's|admin/services/openlist|admin/nas/openlist|g' feeds/luci/applications/luci-app-openlist/root/usr/share/luci/menu.d/luci-app-openlist.json 2>/dev/null || true

# 文件管理 → 服务菜单 (LEDE feeds 默认在 system)
sed -i 's|admin/system/filebrowser|admin/services/filebrowser|g' feeds/luci/applications/luci-app-filebrowser/root/usr/share/luci/menu.d/luci-app-filebrowser.json 2>/dev/null || true

# 网络唤醒 → 网络菜单
sed -i 's|admin/services/wol|admin/network/wol|g' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json 2>/dev/null || true

# 统计 → 网络菜单
sed -i 's|admin/services/nlbw|admin/network/nlbw|g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json 2>/dev/null || true

# ===== GFW 菜单归类 =====
# 修改 LuCI 内置 VPN 类别名称 → GFW
sed -i 's/"title": "VPN"/"title": "GFW"/g' feeds/luci/modules/luci-base/root/usr/share/luci/menu.d/luci-base.json 2>/dev/null || true
sed -i '/^msgid "VPN"$/,/^msgstr/s/^msgstr "VPN"/msgstr "GFW"/' feeds/luci/modules/luci-base/po/zh_Hans/base.po 2>/dev/null || true

# --- OpenClash → GFW 菜单 (vernesong 官方源) ---
# 安全 sed: 只替换 admin/services URL 路径，不影响变量名或翻译文字
find package/openclash -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) -exec sed -i 's|admin/services|admin/vpn|g' {} +
# 在 controller 里声明 GFW 一级菜单
OC_CTRL="package/openclash/luasrc/controller/openclash.lua"
if [ -f "$OC_CTRL" ]; then
	sed -i '/entry({"admin", "vpn"}/!{/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$OC_CTRL"
fi

# --- PassWall → GFW 菜单 (kenzok8/small) ---
# 安全 sed: 只替换 admin/services URL 路径
find package/kenzok8-small/luci-app-passwall -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) -exec sed -i 's|admin/services|admin/vpn|g' {} +
# 在 controller 里声明 GFW 一级菜单
PW_CTRL="package/kenzok8-small/luci-app-passwall/luasrc/controller/passwall.lua"
if [ -f "$PW_CTRL" ]; then
	sed -i '/entry({"admin", "vpn"}/!{/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$PW_CTRL"
fi

# --- SSR-Plus → GFW 菜单 (fw876/helloworld) ---
# 安全 sed: 只替换 admin/services URL 路径
find package/helloworld/luci-app-ssr-plus -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) -exec sed -i 's|admin/services|admin/vpn|g' {} +
# 在 controller 里声明 GFW 一级菜单
SSR_CTRL="package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua"
if [ -f "$SSR_CTRL" ]; then
	sed -i '/entry({"admin", "vpn"}/!{/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$SSR_CTRL"
fi

# --- MosDNS → GFW 菜单 (kenzok8/small，JS-based，使用 menu.d JSON) ---
sed -i 's|admin/services/mosdns|admin/vpn/mosdns|g' package/kenzok8-small/luci-app-mosdns/root/usr/share/luci/menu.d/luci-app-mosdns.json 2>/dev/null || true

# --- ZeroTier → GFW 菜单 (LEDE feeds openwrt-25.12，JS-based，menu.d 已在 admin/vpn/) ---
# LEDE feeds 新版 ZeroTier 菜单已在 admin/vpn/，无需修改

# --- IPSec → GFW 菜单 (LEDE feeds openwrt-25.12，JS-based，menu.d 已在 admin/vpn/) ---
# LEDE feeds 新版 IPSec 菜单已在 admin/vpn/，无需修改

# ===== AdGuard Home 保留在服务菜单 =====

# ===== 权限修复 =====
chmod -R 755 package/kenzok8 package/kenzok8-small package/openclash package/helloworld
