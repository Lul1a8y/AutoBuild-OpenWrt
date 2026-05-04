#!/bin/bash
# https://github.com/Lul1a8y/AutoBuild-OpenWrt
# Updated diy-part.sh — 权威插件源 + AdGuard Home + 内核6.6
# 插件源分工:
#   kenzok8/openwrt-packages → luci-app + 独立服务 (adguardhome, smartdns 等)
#   kenzok8/small            → 代理类 (passwall, mosdns) + 核心依赖 (sing-box, xray 等)
#   vernesong/OpenClash      → OpenClash 官方最新版
#   fw876/helloworld         → SSR-Plus 官方最新版

# ===== 内核锁定 6.6 LTS =====
sed -i 's/KERNEL_PATCHVER:=6.12/KERNEL_PATCHVER:=6.6/g' target/linux/x86/Makefile

# ===== 修改默认IP =====
sed -i "s/192.168.1.1/192.168.50.10/g" package/base-files/files/bin/config_generate

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

# ===== 状态 =====
rm -rf feeds/luci/applications/luci-app-netdata
git clone https://github.com/sirpdboy/luci-app-netdata feeds/luci/applications/luci-app-netdata

# ===== UI 汉化微调（保留原作者风格） =====
# 系统
sed -i 's/"管理权"/"改密码"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
# 服务
sed -i 's/ShadowSocksR Plus+/SSR Plus+/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua 2>/dev/null || true
sed -i 's/msgstr "KMS 服务器"/msgstr "KMS 服务"/g' feeds/luci/applications/luci-app-vlmcsd/po/zh_Hans/vlmcsd.po 2>/dev/null || true
sed -i 's/msgstr "UPnP"/msgstr "UPnP设置"/g' feeds/luci/applications/luci-app-upnp/po/zh_Hans/upnp.po 2>/dev/null || true
# 管控
sed -i 's/"上网时间控制"/"上网控制"/g' feeds/luci/applications/luci-app-accesscontrol/po/zh-cn/mia.po 2>/dev/null || true
# 存储
sed -i 's/msgstr "AList"/msgstr "网盘挂载"/g' feeds/luci/applications/luci-app-alist/po/zh_Hans/alist.po 2>/dev/null || true
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
# ttyd → 系统菜单
sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json 2>/dev/null || true
# 上网时间控制 → 管控菜单
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/controller/mia.lua 2>/dev/null || true
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/view/mia/mia_status.htm 2>/dev/null || true
# AList → NAS 菜单
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d/luci-app-alist.json 2>/dev/null || true
# 文件管理 → NAS 菜单
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-filebrowser/root/usr/share/luci/menu.d/luci-app-filebrowser.json 2>/dev/null || true
# 网络唤醒 → 网络菜单
sed -i 's/services/network/g' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json 2>/dev/null || true
# 统计 → 网络菜单
sed -i 's/services/network/g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json 2>/dev/null || true

# ===== GFW 菜单归类 =====
# --- OpenClash → GFW 菜单 (vernesong 官方源) ---
OC_CTRL="package/openclash/luasrc/controller/openclash.lua"
if [ -f "$OC_CTRL" ]; then
sed -i '/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$OC_CTRL"
sed -i 's/"admin", "services"/"admin", "vpn"/g' "$OC_CTRL"
sed -i 's/services/vpn/g' package/openclash/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/openclash/luasrc/model/cbi/openclash/*.lua
sed -i 's/services/vpn/g' package/openclash/luasrc/view/openclash/*.htm
fi

# --- PassWall → GFW 菜单 (kenzok8/small) ---
PW_CTRL="package/kenzok8-small/luci-app-passwall/luasrc/controller/passwall.lua"
if [ -f "$PW_CTRL" ]; then
	sed -i '/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$PW_CTRL"
	sed -i 's/"admin", "services"/"admin", "vpn"/g' "$PW_CTRL"
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/controller/*.lua
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/passwall/*.lua
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/model/cbi/passwall/client/*.lua
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/model/cbi/passwall/server/*.lua
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/app_update/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/auto_switch/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/global/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/haproxy/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/log/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/node_list/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/node_config/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/node_subscribe/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/rule/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/rule_list/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/server/*.htm
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/socks_auto_switch/*.htm 2>/dev/null || true
fi
# --- PassWall2 → GFW 菜单 (kenzok8/small) ---
PW2_CTRL="package/kenzok8-small/luci-app-passwall2/luasrc/controller/passwall2.lua"
if [ -f "$PW2_CTRL" ]; then
	sed -i '/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$PW2_CTRL"
	sed -i 's/"admin", "services"/"admin", "vpn"/g' "$PW2_CTRL"
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall2/luasrc/controller/*.lua
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall2/luasrc/passwall2/*.lua
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall2/luasrc/model/cbi/passwall2/*.lua
	sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall2/luasrc/view/passwall2/*.htm 2>/dev/null || true
fi

# --- SSR-Plus → GFW 菜单 (fw876/helloworld) ---
SSR_CTRL="package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua"
if [ -f "$SSR_CTRL" ]; then
sed -i '/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$SSR_CTRL"
sed -i 's/"admin", "services"/"admin", "vpn"/g' "$SSR_CTRL"
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/model/cbi/shadowsocksr/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/view/shadowsocksr/*.htm
fi

# --- Zerotier → GFW 菜单 ---
ZT_CTRL="feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua"
if [ -f "$ZT_CTRL" ]; then
sed -i '/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$ZT_CTRL"
sed -i 's/"admin", "services"/"admin", "vpn"/g' "$ZT_CTRL"
fi

# --- IPSec → GFW 菜单 ---
IPSEC_CTRL="feeds/luci/applications/luci-app-ipsec-vpnd/luasrc/controller/ipsec-server.lua"
if [ -f "$IPSEC_CTRL" ]; then
sed -i '/entry({"admin", "services"}/i entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$IPSEC_CTRL"
sed -i 's/"admin", "services"/"admin", "vpn"/g' "$IPSEC_CTRL"
fi

# ===== AdGuard Home 菜单归类 → 服务 =====
AGH_CTRL="package/kenzok8/luci-app-adguardhome/luasrc/controller/adguardhome.lua"
if [ -f "$AGH_CTRL" ]; then
  # AdGuard Home 保留在服务菜单，不做移动
  true
fi

# ===== 权限修复 =====
chmod -R 755 package/kenzok8 package/kenzok8-small package/openclash package/helloworld


