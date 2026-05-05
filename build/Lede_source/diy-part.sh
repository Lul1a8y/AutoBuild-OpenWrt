#!/bin/bash
# https://github.com/Lul1a8y/AutoBuild-OpenWrt
# diy-part.sh — 权威插件源 + AdGuard Home + MosDNS + 内核6.6

# ===== 内核锁定 6.6 LTS =====
sed -i 's/KERNEL_PATCHVER:=6.12/KERNEL_PATCHVER:=6.6/g' target/linux/x86/Makefile

# ===== 修改默认IP =====
sed -i "s/192.168.1.1/192.168.50.2/g" package/base-files/files/bin/config_generate

# ===== ttyd 终端需密码登录 =====
sed -i '7a uci set system.@system[0].ttylogin=1' package/lean/default-settings/files/zzz-default-settings

# ===== 添加权威插件源 =====
git clone https://github.com/kenzok8/openwrt-packages package/kenzok8
git clone https://github.com/kenzok8/small package/kenzok8-small

# ===== 从 coolsnowwolf/luci master 分支补充 filetransfer（openwrt-25.12 分支没有此包） =====
svn export https://github.com/coolsnowwolf/luci/branches/master/applications/luci-app-filetransfer feeds/luci/applications/luci-app-filetransfer

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
git clone -b master https://github.com/vernesong/OpenClash.git package/openclash
git clone -b master https://github.com/fw876/helloworld package/helloworld

# ===== AdGuard Home =====
# 核心: package/kenzok8/adguardhome | Luci: package/kenzok8/luci-app-adguardhome
# 依赖: kenzok8/small 提供

# ===== 删除 kenzok8 里与 LEDE feeds 冲突的包 =====
rm -rf package/kenzok8/luci-app-filebrowser

# ===== 修复 kenzok8 嵌套目录结构 =====
for _dir in package/kenzok8/*/; do
  _pkg=$(basename "$_dir")
  if [ -d "${_dir}${_pkg}" ] && [ -f "${_dir}${_pkg}/Makefile" ] && [ ! -f "${_dir}Makefile" ]; then
    mv "${_dir}${_pkg}"/* "${_dir}" 2>/dev/null
    rm -rf "${_dir}${_pkg}"
  fi
done

# ===== UI 汉化微调 =====
sed -i 's/"管理权"/"改密码"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/ShadowSocksR Plus+/SSR Plus+/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua 2>/dev/null || true
sed -i 's/msgstr "KMS 服务器"/msgstr "KMS 服务"/g' feeds/luci/applications/luci-app-vlmcsd/po/zh_Hans/vlmcsd.po 2>/dev/null || true
sed -i 's/msgstr "UPnP"/msgstr "UPnP设置"/g' feeds/luci/applications/luci-app-upnp/po/zh_Hans/upnp.po 2>/dev/null || true
sed -i 's/"上网时间控制"/"上网控制"/g' feeds/luci/applications/luci-app-accesscontrol/po/zh-cn/mia.po 2>/dev/null || true
sed -i 's/msgstr "OpenList"/msgstr "网盘挂载"/g' feeds/luci/applications/luci-app-openlist/po/zh_Hans/openlist.po 2>/dev/null || true
sed -i 's/msgstr "FileBrowser"/msgstr "文件管理"/g' feeds/luci/applications/luci-app-filebrowser/po/zh_Hans/filebrowser.po 2>/dev/null || true
sed -i 's/msgstr "FTP 服务器"/msgstr "FTP 服务"/g' feeds/luci/applications/luci-app-vsftpd/po/zh_Hans/vsftpd.po 2>/dev/null || true
sed -i 's/msgstr "qbittorrent"/msgstr "qb下载"/g' feeds/luci/applications/luci-app-qbittorrent/po/zh_Hans/qbittorrent.po 2>/dev/null || true
sed -i 's/IPSec VPN 服务器/IPSec 服务/g' feeds/luci/applications/luci-app-ipsec-vpnd/po/zh_Hans/ipsec.po 2>/dev/null || true
sed -i '18d' feeds/luci/applications/luci-app-arpbind/po/zh_Hans/arpbind.po 2>/dev/null || true
sed -i '17a msgstr "MAC绑定"' feeds/luci/applications/luci-app-arpbind/po/zh_Hans/arpbind.po 2>/dev/null || true
sed -i 's/msgstr "Socat"/msgstr "端口转发"/g' feeds/luci/applications/luci-app-socat/po/zh_Hans/socat.po 2>/dev/null || true
sed -i 's/Turbo ACC 网络加速/网络加速/g' feeds/luci/applications/luci-app-turboacc/po/zh-cn/turboacc.po 2>/dev/null || true
sed -i 's/网络存储/存储/g' feeds/luci/applications/luci-app-vsftpd/po/zh_Hans/vsftpd.po 2>/dev/null || true
sed -i 's/带宽监控/统计/g' feeds/luci/applications/luci-app-nlbwmon/po/zh_Hans/nlbwmon.po 2>/dev/null || true

# ===== 欢迎页信息 =====
sed -i '63d' package/lean/autocore/files/x86/index.htm 2>/dev/null || true
sed -i '62a localtime = os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X"),' package/lean/autocore/files/x86/index.htm 2>/dev/null || true
sed -i '750a <tr><td width="33%"><%:固件编译日期%></td><td id="cpuusage">Lul1a8y 2026.05.04</td></tr>' package/lean/autocore/files/x86/index.htm 2>/dev/null || true
sed -i "s/2026.05.04/$(TZ=UTC-8 date \"+%Y.%m.%d\")/g" package/lean/autocore/files/x86/index.htm 2>/dev/null || true

# ===== 调整菜单归类 =====
# 上网时间控制 → 管控菜单
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/controller/mia.lua 2>/dev/null || true
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/view/mia/mia_status.htm 2>/dev/null || true
sed -i 's|admin/services|admin/control|g' feeds/luci/applications/luci-app-accesscontrol/root/usr/share/luci/menu.d/luci-app-accesscontrol.json 2>/dev/null || true
# OpenList → NAS 菜单
sed -i 's|admin/services/openlist|admin/nas/openlist|g' feeds/luci/applications/luci-app-openlist/root/usr/share/luci/menu.d/luci-app-openlist.json 2>/dev/null || true
# 网络唤醒 → 网络菜单
sed -i 's/services/network/g' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json 2>/dev/null || true
# 统计 → 网络菜单
sed -i 's/services/network/g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json 2>/dev/null || true
# 文件管理(FileBrowser) → 服务菜单
sed -i 's|admin/nas/filebrowser|admin/services/filebrowser|g' feeds/luci/applications/luci-app-filebrowser/root/usr/share/luci/menu.d/luci-app-filebrowser.json 2>/dev/null || true

# ===== GFW 菜单归类 =====
# 修改 LuCI 内置 VPN 类别名称 → GFW
sed -i 's/"title": "VPN"/"title": "GFW"/g' feeds/luci/modules/luci-base/root/usr/share/luci/menu.d/luci-base.json 2>/dev/null || true
sed -i '/^msgid "VPN"$/,/^msgstr/s/^msgstr "VPN"/msgstr "GFW"/' feeds/luci/modules/luci-base/po/zh_Hans/base.po 2>/dev/null || true

# --- OpenClash → GFW 菜单 (vernesong 官方源) ---
OC_CTRL="package/openclash/luasrc/controller/openclash.lua"
if [ -f "$OC_CTRL" ]; then
  # 在第一个 entry 前插入 GFW 一级菜单声明
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$OC_CTRL"
fi
# 全目录替换 services→vpn
sed -i 's/services/vpn/g' package/openclash/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/openclash/luasrc/model/cbi/openclash/*.lua
sed -i 's/services/vpn/g' package/openclash/luasrc/view/openclash/*.htm

# --- PassWall → GFW 菜单 (kenzok8/small) ---
PW_CTRL="package/kenzok8-small/luci-app-passwall/luasrc/controller/passwall.lua"
if [ -f "$PW_CTRL" ]; then
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$PW_CTRL"
fi
# 全目录替换 services→vpn — 覆盖所有子目录
# api.lua 里有 string.format("admin/services/%s", appname) 必须 s/services/vpn/g 才能改到
sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/model/cbi/passwall/client/*.lua
sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/model/cbi/passwall/server/*.lua
sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/passwall/*.lua
sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/luasrc/view/passwall/app_update/*.htm
sed -i 's/services/vpn/g' package/kenzok8-small/luci-app-passwall/htdocs/luci-static/resources/view/passwall/*.js 2>/dev/null || true

# --- SSR-Plus → GFW 菜单 (fw876/helloworld) ---
SSR_CTRL="package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua"
if [ -f "$SSR_CTRL" ]; then
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$SSR_CTRL"
fi
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/model/cbi/shadowsocksr/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/view/shadowsocksr/*.htm

# --- MosDNS → GFW 菜单 (kenzok8/small, JS-based, 使用 menu.d JSON) ---
sed -i 's|admin/services/mosdns|admin/vpn/mosdns|g' package/kenzok8-small/luci-app-mosdns/root/usr/share/luci/menu.d/luci-app-mosdns.json 2>/dev/null || true

# --- ZeroTier & IPSec → LEDE feeds openwrt-25.12 已在 admin/vpn/，无需修改 ---

# ===== AdGuard Home 保留在服务菜单 =====

# ===== 权限修复 =====
chmod -R 755 package/kenzok8 package/kenzok8-small package/openclash package/helloworld
