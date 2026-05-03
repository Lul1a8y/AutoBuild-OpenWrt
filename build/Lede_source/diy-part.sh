#!/bin/bash
# https://github.com/Lul1a8y/AutoBuild-OpenWrt
# Updated diy-part.sh — 权威插件源 + AdGuard Home + 内核6.6
# 插件源分工:
#   kenzok8/openwrt-packages → luci-app + 独立服务 (adguardhome, smartdns, ddns-go 等)
#   kenzok8/small            → 代理类 (openclash, passwall, ssr-plus, mosdns) + 核心依赖
#   fw876/helloworld         → SSR-Plus 最新版 (官方源)
#   vernesong/OpenClash      → OpenClash 最新版 (官方源)

# ===== 内核锁定 6.6 LTS =====
sed -i 's/KERNEL_PATCHVER:=6.12/KERNEL_PATCHVER:=6.6/g' target/linux/x86/Makefile

# ===== 修改默认IP =====
sed -i "s/192.168.1.1/192.168.123.254/g" package/base-files/files/bin/config_generate

# ===== ttyd 终端需密码登录 =====
sed -i '7a uci set system.@system[0].ttylogin=1' package/lean/default-settings/files/zzz-default-settings

# ===== 添加权威插件源 =====
# kenzok8/openwrt-packages — luci应用 + 独立服务包
git clone https://github.com/kenzok8/openwrt-packages package/kenzok8
# kenzok8/small — 代理类插件 + 核心依赖库 (passwall, openclash, ssr-plus, mosdns 等)
git clone https://github.com/kenzok8/small package/kenzok8-small

# ===== 删除 LEDE 自带的旧版代理插件，用官方最新源替换 =====
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-ssr-plus
rm -rf feeds/luci/applications/luci-app-mosdns

# OpenClash 官方源 (vernesong)
git clone -b master https://github.com/vernesong/OpenClash.git package/kenzok8/luci-app-openclash
# PassWall 直接用 kenzok8/small 的 (同步上游 xiaorouji)
# SSR-Plus 官方源 (fw876)
git clone -b master https://github.com/fw876/helloworld package/helloworld

# ===== AdGuard Home (kenzok8 源，持续维护) =====
# adguardhome 核心包在 kenzok8/openwrt-packages
# luci-app-adguardhome 在 kenzok8/openwrt-packages
# 依赖库在 kenzok8/small

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
# OpenClash (vernesong 官方源)
sed -i '13a entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' package/kenzok8/luci-app-openclash/luasrc/controller/openclash.lua 2>/dev/null || true
find package/kenzok8/luci-app-openclash -name "*.lua" -o -name "*.htm" | xargs sed -i 's/services/vpn/g' 2>/dev/null || true

# PassWall (kenzok8/small)
sed -i '13a entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' package/kenzok8-small/luci-app-passwall/luasrc/controller/passwall.lua 2>/dev/null || true
find package/kenzok8-small/luci-app-passwall -name "*.lua" -o -name "*.htm" | xargs sed -i 's/services/vpn/g' 2>/dev/null || true

# SSR-Plus (fw876/helloworld)
sed -i '12a entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua 2>/dev/null || true
find package/helloworld/luci-app-ssr-plus -name "*.lua" -o -name "*.htm" | xargs sed -i 's/services/vpn/g' 2>/dev/null || true

# Zerotier
sed -i '8d' feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua 2>/dev/null || true
sed -i '7a entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua 2>/dev/null || true
# IPSec
sed -i '8d' feeds/luci/applications/luci-app-ipsec-vpnd/luasrc/controller/ipsec-server.lua 2>/dev/null || true
sed -i '7a entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' feeds/luci/applications/luci-app-ipsec-vpnd/luasrc/controller/ipsec-server.lua 2>/dev/null || true

# ===== 权限修复 =====
chmod -R 755 package/kenzok8 package/kenzok8-small package/helloworld
