#!/bin/bash
# https://github.com/Lul1a8y/AutoBuild-OpenWrt
# diy-part.sh — 权威插件源 + AdGuard Home + MosDNS + 内核6.6

# ===== 内核锁定 6.6 LTS =====
sed -i 's/KERNEL_PATCHVER:=6.12/KERNEL_PATCHVER:=6.6/g' target/linux/x86/Makefile

# ===== ttyd 终端需密码登录 =====
sed -i '7a uci set system.@system[0].ttylogin=1' package/lean/default-settings/files/zzz-default-settings

# ===== 添加权威插件源 =====
git clone https://github.com/kenzok8/openwrt-packages package/kenzok8
git clone https://github.com/kenzok8/small package/kenzok8-small

# ===== 默认IP 192.168.50.2 =====
sed -i "s/192.168.1.1/192.168.50.2/g" package/base-files/files/bin/config_generate

# ===== 主机名 Openwrt =====
sed -i "s/hostname='LEDE'/hostname='Openwrt'/g" package/base-files/files/bin/config_generate

# ===== 删除 feeds 冲突包（用权威源/官方源替换） =====
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf package/kenzok8-small/luci-app-passwall2

# ===== 删除 kenzok8/small 里自带的 openclash/ssr-plus，用官方最新源替换 =====
rm -rf package/kenzok8-small/luci-app-openclash
rm -rf package/kenzok8-small/luci-app-ssr-plus

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

# --- 系统菜单→文件传输（上传+安装ipk）---
# 从 coolsnowwolf/luci master 分支获取，openwrt-25.12 已移除该包
git clone --depth 1 -b master --single-branch https://github.com/coolsnowwolf/luci.git /tmp/ft-luci
cp -r /tmp/ft-luci/applications/luci-app-filetransfer package/
rm -rf /tmp/ft-luci
# 添加 zh_Hans 翻译（旧 po 用 zh-cn，新 luci 用 zh_Hans）
mkdir -p package/luci-app-filetransfer/po/zh_Hans
cat > package/luci-app-filetransfer/po/zh_Hans/filetransfer.po << 'POEOF'
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
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$OC_CTRL"
  # 再做 services→vpn 替换
  find package/openclash -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
    -exec sed -i 's/services/vpn/g' {} +
fi

# --- PassWall → GFW 菜单 (kenzok8/small) ---
PW_CTRL=$(find package/kenzok8-small -path '*/controller/passwall.lua' -print -quit 2>/dev/null)
if [ -n "$PW_CTRL" ] && [ -f "$PW_CTRL" ]; then
  # 先插入 GFW 父类别
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$PW_CTRL"
  # 再做 services→vpn 替换（覆盖 api.lua 的 string.format 等所有路径引用）
  find package/kenzok8-small/luci-app-passwall -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
    -exec sed -i 's/services/vpn/g' {} +
fi

# --- SSR-Plus → GFW 菜单 (fw876/helloworld) ---
SSR_CTRL=$(find package/helloworld -path '*/controller/shadowsocksr.lua' -print -quit 2>/dev/null)
if [ -n "$SSR_CTRL" ] && [ -f "$SSR_CTRL" ]; then
  # 先插入 GFW 父类别
  sed -i '/entry({"admin", "services"}/i\	entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' "$SSR_CTRL"
  # 再做 services→vpn 替换（覆盖 url 函数和 build_url 调用）
  find package/helloworld/luci-app-ssr-plus -type f \( -name '*.lua' -o -name '*.htm' -o -name '*.js' \) \
    -exec sed -i 's/services/vpn/g' {} +
fi

# --- MosDNS → GFW 菜单 (kenzok8/small, JS-based, 使用 menu.d JSON) ---
sed -i 's|admin/services/mosdns|admin/vpn/mosdns|g' package/kenzok8-small/luci-app-mosdns/root/usr/share/luci/menu.d/luci-app-mosdns.json 2>/dev/null || true

# --- ZeroTier & IPSec → LEDE feeds openwrt-25.12 已在 admin/vpn/，无需修改 ---

# ===== AdGuard Home 保留在服务菜单 =====

# ===== 权限修复 =====
chmod -R 755 package/kenzok8 package/kenzok8-small package/openclash package/helloworld
