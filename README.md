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
| 192.168.50.2 | root | password | 12306 |

**注意：默认 root 密码是上游 lede 的默认值 `password`，未做修改 —— 首次登录后请立即改掉。**

**构建期注入与可追溯（2026-10-09 起）**

- **OpenClash 控制面板密码不再写死在仓库里**：构建时注入。仓库 secret `OPENCLASH_DASH_PASS` 优先，未配置则每次构建随机生成。
  在路由器上查看方式：`uci get openclash.@config[0].dashboard_password`
- 每次构建的 release 里附带 **`BUILD_SOURCE.txt`** 和 **`SOURCE_LOCK.txt`**：记录本次固件对应的 AutoBuild-OpenWrt commit、lede / feeds 各源 commit、`.config` 的 sha256；`SOURCE_LOCK.txt` 是编译前的快照，便于事后核对和回滚。
- 固件版本号由 `.github/workflows/compile-openwrt.yml` 的 `FIRMWARE_VER` 按构建日期生成（`RYY.MM.DD`，单一来源）；如需固定版本，只改这一处。
- release 里保留 `*sha256sums*` / `*manifest*` / `*buildinfo*`，可用于校验与包清单核对。

**仓库 secret**

| secret | 用途 | 必填 |
| ---- | ---- | ---- |
| `REPO_TOKEN` | 发布 release / 云端更新（repo 级 PAT） | 是 |
| `FIRMWARE_SIGN_KEY_B64` | `.sha256` 清单的 Ed25519 私钥（base64） | `REGULAR_UPDATE=true` 时必填 |
| `TELEGRAM_BOT_TOKEN`、`TELEGRAM_CHAT_ID` | 构建通知 | 否 |
| `OPENCLASH_DASH_PASS` | OpenClash 面板密码（不配置则随机生成） | 否 |

**固件签名密钥（`FIRMWARE_SIGN_KEY_B64`）**

`REGULAR_UPDATE=true` 时，工作流会用 Ed25519 给每个 `<固件>.sha256` 清单签名，设备端用固件内置的 `/etc/firmware-signing.pub` 验签。生成方法：

```sh
openssl genpkey -algorithm ED25519 -out fw-signing.pem
openssl pkey -in fw-signing.pem -pubout \
  -out build/Lede_source/files/etc/firmware-signing.pub
base64 -w0 fw-signing.pem
```

把最后一行输出存到 GitHub secret `FIRMWARE_SIGN_KEY_B64`；`fw-signing.pem` 和 `*.key` 不要提交。生成命令会把公钥写到 `build/Lede_source/files/etc/firmware-signing.pub`，记得把它一并提交/替换仓库里的旧公钥。

轮换密钥后，旧固件设备内置的是旧公钥，会拒收新固件，需要手动刷一次新固件。

> 未配置该 secret 时，`REGULAR_UPDATE=true` 的构建会在「检查签名密钥」步骤提前失败，不会等 5 小时编译完才报错。

**刷机后验收自检**

`scripts/router-acceptance.sh` 是只读的实机验收脚本：检查四口映射 / EEE 与 igc 健康 / PPPoE 与 MTU-MSS / IPv6 / DNS 链 / 代理分流 / offload / 存储，输出 `PASS` / `WARN` / `FAIL` 三态，退出码等于 FAIL 数量（0 = 全通过）。

```sh
# 在路由器上执行（需要 SSH 可达，默认 192.168.50.2:12306）
scp scripts/router-acceptance.sh root@192.168.50.2:/tmp/
ssh -p 12306 root@192.168.50.2 sh /tmp/router-acceptance.sh
```

脚本全程只读：不改 uci、不重启服务、不打印任何密码字段。建议每次刷完固件跑一遍再开始配置。

**固件特性**

- 源码：coolsnowwolf/lede master 分支
- 内核：6.18 LTS（main 已 pin 6.18；kernel-6.18-test 为验证分支）
- LuCI：23.05
- 插件源：kenzok8/openwrt-packages + kenzok8/small + vernesong/OpenClash + fw876/helloworld
- GFW 菜单归类：OpenClash / PassWall / SSR-Plus / ZeroTier / IPSec
- 中文菜单重命名：改密码 / 网盘挂载 / 文件管理 / 端口转发 / 网络加速 等
- PVE 虚拟平台：下载 `*-squashfs-combined-efi.img` 镜像，使用 `qm importdisk` 导入

**主要插件**

OpenClash / PassWall / SSR-Plus / AdGuard Home / OpenList(文件管理, 原 AList) / ZeroTier / ttyd / netdata / Diskman

> AdGuard Home 默认只装 `luci-app-adguardhome` 壳，**不打包核心**。刷完固件后在 LuCI 页面点“更新核心”下载，或手动放入 `/usr/bin/AdGuardHome`；`/etc/AdGuardHome.yaml` 和已下载的核心会被 `keep.d` 保留，升级后还原设置即可。

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
