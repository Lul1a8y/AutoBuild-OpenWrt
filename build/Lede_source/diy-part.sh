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
svn export https://github.com/coolsnowwolf/luci/branches/master/applications/luci-app-filetransfer

# ===== 删除 feeds 冲突包（用权威源/官方源替换） =====
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf package/kenzok8-small/luci-app-passwall2

# ===== 删除 kenzok8/small 里自带的 openclash/ssr-plus，用官方最新源替换 =====
rm -rf package/kenzok8-small/luci-app-openclash

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

# ===== 翻译微调 =====
sed -i 's/"管理权"/"改密码"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po

# --- AdGuard Home ---
# 核心: package/kenzok8/adguardhome | Luci: package/kenzok8/luci-app-adguardhome
# 保留在服务菜单，不做路径修改

# --- 文件浏览器翻译 ---
sed -i 's/msgstr "FileBrowser"/msgstr "文件管理"/g' feeds/luci/applications/luci-app-filebrowser/po/zh_Hans/filebrowser.po 2>/dev/null || true

# --- UPnP 翻译 ---
sed -i 's/msgstr "UPnP"/msgstr "UPnP设置"/g' feeds/luci/applications/luci-app-upnp/po/zh_Hans/upnp.po 2>/dev/null || true

# ===== 菜单归类调整 =====

# --- 访问控制 → 系统/管控 菜单 ---
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/controller/mia.lua 2>/dev/null || true
sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/view/mia/mia_status.htm 2>/dev/null || true
sed -i 's|admin/services|admin/control|g' feeds/luci/applications/luci-app-accesscontrol/root/usr/share/luci/menu.d/luci-app-accesscontrol.json 2>/dev/null || true

# --- OpenList → NAS 菜单 ---
sed -i 's|admin/services/openlist|admin/nas/openlist|g' feeds/luci/applications/luci-app-openlist/root/usr/share/luci/menu.d/luci-app-openlist.json 2>/dev/null || true

# --- 文件浏览器 → 服务菜单 (从 NAS 移过来) ---
sed -i 's|admin/nas/filebrowser|admin/services/filebrowser|g' feeds/luci/applications/luci-app-filebrowser/root/usr/share/luci/menu.d/luci-app-filebrowser.json 2>/dev/null || true

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

# --- OpenClash → GFW 菜单 (vernesong 官方源) ---
# 注意：vernesong/OpenClash clone 到 package/openclash/ 后，
# 实际包目录在 package/openclash/luci-app-openclash/ 下（多一层）
# 使用 find 递归搜索，不怕目录层级变化
find package/openclash -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
  -exec sed -i 's|admin/services|admin/vpn|g' {} +
# 用 find 定位 controller 文件，避免硬编码路径错误
OC_CTRL=$(find package/openclash -path '*/controller/openclash.lua' -print -quit 2>/dev/null)
if [ -n "$OC_CTRL" ] && [ -f "$OC_CTRL" ]; then
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$OC_CTRL"
fi

# --- PassWall → GFW 菜单 (kenzok8/small) ---
# 使用 find 递归搜索，覆盖所有子目录（包括 api.lua 的 string.format）
find package/kenzok8-small/luci-app-passwall -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
  -exec sed -i 's|admin/services|admin/vpn|g' {} +
# 用 find 定位 controller 文件
PW_CTRL=$(find package/kenzok8-small -path '*/controller/passwall.lua' -print -quit 2>/dev/null)
if [ -n "$PW_CTRL" ] && [ -f "$PW_CTRL" ]; then
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$PW_CTRL"
fi

# --- SSR-Plus → GFW 菜单 (fw876/helloworld) ---
find package/helloworld/luci-app-ssr-plus -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
  -exec sed -i 's|admin/services|admin/vpn|g' {} +
SSR_CTRL=$(find package/helloworld -path '*/controller/shadowsocksr.lua' -print -quit 2>/dev/null)
if [ -n "$SSR_CTRL" ] && [ -f "$SSR_CTRL" ]; then
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$SSR_CTRL"
fi

# --- MosDNS → GFW 菜单 (kenzok8/small, JS-based, 使用 menu.d JSON) ---
sed -i 's|admin/services/mosdns|admin/vpn/mosdns|g' package/kenzok8-small/luci-app-mosdns/root/usr/share/luci/menu.d/luci-app-mosdns.json 2>/dev/null || true

# --- ZeroTier & IPSec → LEDE feeds openwrt-25.12 已在 admin/vpn/，无需修改 ---

# ===== AdGuard Home 保留在服务菜单 =====

# ===== 权限修复 =====
chmod -R 755 package/kenzok8 package/kenzok8-small package/openclash package/helloworld
