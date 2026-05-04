**x86 固件更新 方式：**
**x86 firmware update Method：**

1. 在**OP后台 系统--更新固件 点击 手动更新** 稍等几分钟 路由重启即可

   In the OP background system - update firmware, click on Manual update. Wait a few minutes for the router to restart

2. **命令行** 或 **SSH 链接** OP **执行以下命令** 完成固件更新

   Command line or SSH link OP execute the following command to complete the firmware update

- 执行 **`bash /bin/AutoUpdate.sh`** 保留配置更新
- Execute bash /bin/AutoUpdate.sh Keep configuration updates
- 执行 **`bash /bin/AutoUpdate.sh -n`** 不保留配置更新
- Execute bash /bin/AutoUpdate.sh -n Do not keep configuration updates

**注意：LuCI 23.05 与旧版 18.06 不兼容，不能保留配置升级，建议全新安装后重新设置**

Note: LuCI 23.05 is incompatible with the old 18.06, cannot preserve config on upgrade, recommended to reinstall and reconfigure

**x86 OpenWrt 固件默认信息**

| 默认登陆IP | 默认账号 | 默认密码 | SSH端口 |
| ---- | ---- | ---- | ---- |
| 192.168.50.10 | root | password | 12306 |

**固件特性**

- 源码：coolsnowwolf/lede master 分支
- 内核：6.6 LTS
- LuCI：23.05
- 插件源：kenzok8/openwrt-packages + kenzok8/small + vernesong/OpenClash + fw876/helloworld
- GFW 菜单归类：OpenClash / PassWall / SSR-Plus / ZeroTier / IPSec
- 中文菜单重命名：改密码 / 网盘挂载 / 文件管理 / 端口转发 / 网络加速 等
- PVE 虚拟平台：下载 `*-squashfs-combined-efi.img` 镜像，使用 `qm importdisk` 导入

**主要插件**

OpenClash / PassWall / SSR-Plus / AdGuard Home / AList / FileBrowser / ZeroTier / ttyd / netdata / Diskman

固件页面 Firmware page

![image](https://raw.githubusercontent.com/Lul1a8y/AutoBuild-OpenWrt/main/img/opimg.png)

# 感谢 thank

- [大雕 源码仓库](https://github.com/coolsnowwolf/lede.git)
- [kenzok8 插件源](https://github.com/kenzok8/openwrt-packages)
- [vernesong OpenClash](https://github.com/vernesong/OpenClash)
- [fw876 helloworld](https://github.com/fw876/helloworld)
- [P3TERX 自动编译脚本](https://github.com/P3TERX/Actions-OpenWrt)
- [Hyy2001X 定时更新脚本](https://github.com/Hyy2001X/AutoBuild-Actions)
- [gd0772 原版 AutoBuild-OpenWrt](https://github.com/gd0772/AutoBuild-OpenWrt)
