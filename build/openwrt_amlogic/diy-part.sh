#!/bin/bash
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
# DIY扩展二合一了，在此处可以增加插件

# 添加插件源
git clone https://github.com/kenzok8/openwrt-packages package/kenzok8
git clone https://github.com/kenzok8/small package/kenzok8-small

# 删除重复插件（避免与 feeds 冲突）
rm -rf ./feeds/luci/themes/luci-theme-argon
rm -rf ./feeds/luci/themes/luci-theme-netgear
rm -rf ./feeds/luci/themes/luci-theme-material
rm -rf ./feeds/luci/applications/luci-app-socat
rm -rf ./feeds/luci/applications/luci-app-unblockmusic
rm -rf ./feeds/luci/applications/luci-app-rp-pppoe-server

# 修改默认IP
sed -i "s/192.168.1.1/192.168.50.10/g" package/base-files/files/bin/config_generate

# 添加 SSR Plus+
git clone https://github.com/fw876/helloworld package/helloworld
sed -i '/entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false/d' package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua 2>/dev/null
sed -i '12a entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua

# 添加 OpenClash
rm -rf package/kenzok8/luci-app-openclash package/kenzok8-small/luci-app-openclash 2>/dev/null
git clone -b master https://github.com/vernesong/OpenClash.git package/openclash

# 添加 PassWall
git clone https://github.com/xiaorouji/openwrt-passwall package/passwall
git clone -b luci https://github.com/xiaorouji/openwrt-passwall
mv openwrt-passwall/luci-app-passwall package/passwall
rm -rf openwrt-passwall
sed -i '16a entry({"admin", "vpn"}, firstchild(), "GFW", 45).dependent = false' package/passwall/luci-app-passwall2/luasrc/controller/passwall2.lua

# 添加 PassWall2
git clone https://github.com/xiaorouji/openwrt-passwall2 package/passwall2

# 添加 SmartDNS
git clone https://github.com/pymumu/luci-app-smartdns.git -b lede ./package/kenzok8/luci-app-smartdns
git clone https://github.com/pymumu/openwrt-smartdns.git ./feeds/packages/net/smartdns

# 添加 微信推送
git clone https://github.com/tty228/luci-app-serverchan.git ./package/kenzok8/luci-app-serverchan

# 汉化 实时监控
rm -rf ./feeds/luci/applications/luci-app-netdata
git clone https://github.com/sirpdboy/luci-app-netdata feeds/luci/applications/luci-app-netdata

# 插件重命名
sed -i 's/"管理权"/"改密码"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
sed -i 's/TTYD 终端/命令行/g' feeds/luci/applications/luci-app-ttyd/po/zh-cn/terminal.po
sed -i 's/ShadowSocksR Plus+/SSR Plus+/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua
sed -i 's/PassWall/Pass Wall/g' package/passwall/luci-app-passwall/po/zh-cn/passwall.po
sed -i 's/广告屏蔽大师 Plus+/广告屏蔽/g' feeds/luci/applications/luci-app-adbyby-plus/po/zh-cn/adbyby.po
sed -i 's/msgstr "KMS 服务器"/msgstr "KMS 激活"/g' feeds/luci/applications/luci-app-vlmcsd/po/zh-cn/vlmcsd.po
sed -i 's/msgstr "UPnP"/msgstr "UPnP设置"/g' feeds/luci/applications/luci-app-upnp/po/zh-cn/upnp.po
sed -i 's/Frp 内网穿透/Frp 客户端/g' feeds/luci/applications/luci-app-frpc/po/zh-cn/frp.po
sed -i 's/Frps/Frp 服务端/g' feeds/luci/applications/luci-app-frps/luasrc/controller/frps.lua
sed -i 's/Docker CE 容器/Docker容器/g' feeds/luci/applications/luci-app-docker/po/zh-cn/docker.po
sed -i 's/网络存储/存储/g' feeds/luci/applications/luci-app-vsftpd/po/zh-cn/vsftpd.po
sed -i 's/挂载 SMB 网络共享/挂载共享/g' feeds/luci/applications/luci-app-cifs-mount/po/zh-cn/cifs.po
sed -i 's/"文件浏览器"/"文件管理"/g' package/kenzok8/luci-app-filebrowser/po/zh-cn/filebrowser.po 2>/dev/null
sed -i 's/msgstr "FTP 服务器"/msgstr "FTP 服务"/g' feeds/luci/applications/luci-app-vsftpd/po/zh-cn/vsftpd.po
sed -i 's/Rclone/网盘挂载/g' feeds/luci/applications/luci-app-rclone/luasrc/controller/rclone.lua
sed -i 's/msgstr "Aria2"/msgstr "Aria2下载"/g' feeds/luci/applications/luci-app-aria2/po/zh-cn/aria2.po
sed -i 's/firstchild(), "VPN"/firstchild(), "GFW"/g' feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua
sed -i 's/firstchild(), "VPN"/firstchild(), "GFW"/g' feeds/luci/applications/luci-app-softethervpn/luasrc/controller/softethervpn.lua
sed -i 's/WireGuard 状态/WiGd状态/g' feeds/luci/applications/luci-app-wireguard/po/zh-cn/wireguard.po
sed -i 's/Turbo ACC 网络加速/网络加速/g' feeds/luci/applications/luci-app-turboacc/po/zh-cn/turboacc.po
sed -i 's/MWAN3 分流助手/分流助手/g' feeds/luci/applications/luci-app-mwan3helper/po/zh-cn/mwan3helper.po
sed -i 's/带宽监控/统计/g' feeds/luci/applications/luci-app-nlbwmon/po/zh-cn/nlbwmon.po
sed -i 's/实时流量监测/流量监测/g' feeds/luci/applications/luci-app-wrtbwmon/po/zh-cn/wrtbwmon.po
sed -i 's/msgstr "Socat"/msgstr "端口转发"/g' feeds/luci/applications/luci-app-socat/po/zh-cn/socat.po

# 菜单调整
sed -i 's/\"services\"/\"nas\"/g' feeds/luci/applications/luci-app-samba4/luasrc/controller/samba4.lua
sed -i 's/\"services\"/\"network\"/g' feeds/luci/applications/luci-app-mwan3helper/luasrc/controller/mwan3helper.lua

# 调整代理插件到 GFW 菜单
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/model/cbi/shadowsocksr/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/view/shadowsocksr/*.htm
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/model/cbi/passwall/api/*.lua
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/*.lua
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/model/cbi/passwall/server/*.lua
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/view/passwall/app_update/*.htm
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/view/passwall/auto_switch/*.htm
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/view/passwall/global/*.htm
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/view/passwall/log/*.htm
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/view/passwall/node_list/*.htm
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/view/passwall/rule/*.htm
sed -i 's/services/vpn/g' package/passwall/luci-app-passwall/luasrc/view/passwall/server/*.htm
sed -i 's/services/vpn/g' package/openclash/luci-app-openclash/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/openclash/luci-app-openclash/luasrc/*.lua
sed -i 's/services/vpn/g' package/openclash/luci-app-openclash/luasrc/model/cbi/openclash/*.lua
sed -i 's/services/vpn/g' package/openclash/luci-app-openclash/luasrc/view/openclash/*.htm
sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-v2ray-server/luasrc/controller/*.lua
sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-v2ray-server/luasrc/model/cbi/v2ray_server/*.lua
sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-v2ray-server/luasrc/view/v2ray_server/*.htm
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-aliyundrive-webdav/luasrc/controller/*.lua
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-aliyundrive-webdav/luasrc/model/cbi/aliyundrive-webdav/*.lua
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-aliyundrive-webdav/luasrc/view/aliyundrive-webdav/*.htm
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-aria2/luasrc/controller/aria2.lua
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-hd-idle/luasrc/controller/hd_idle.lua

# 权限修复
chmod -R 755 package/kenzok8

# 更新配置
./scripts/feeds install -a

# 设置打包固件的机型，内核组合
cat >$GITHUB_WORKSPACE/amlogic_openwrt <<-EOF
rootfs_size=944
amlogic_model=s905d
amlogic_kernel=5.4.155
EOF
