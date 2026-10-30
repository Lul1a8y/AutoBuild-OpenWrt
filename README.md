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

> 默认命令会保留 `/etc/config`（LAN、PPPoE、ADH 等）；`-n` 不保留，适合全新安装或配置已损坏时。
>
> 普通 OTA 升级会先执行 `sysupgrade -T` 检查镜像兼容性，失败会中止；`sysupgrade -F` 只保留给明确的手动强制刷机。
>
> `AutoUpdate.sh -g` 的旧通道转换菜单（18.06 / 19.07 / 21.02）已停用；这些通道均已 EOL，请手动刷入当前固件。

**注意：LuCI 23.05 与旧版 18.06 不兼容，不能保留配置升级，建议全新安装后重新设置**

Note: LuCI 23.05 is incompatible with the old 18.06, cannot preserve config on upgrade, recommended to reinstall and reconfigure

**x86 OpenWrt 固件默认信息**

| 默认登陆IP | 默认账号 | 默认密码 | SSH端口 |
| ---- | ---- | ---- | ---- |
| 192.168.50.2 | root | password | 12306 |

**注意：默认 root 密码是上游 LEDE 的默认值 `password`，未做修改 —— 首次登录后必须立即改掉。如果设备会接入不可信 LAN，请先通过串口/控制台改密，再接入网络。**

> SSH 默认开启密码认证，建议配置公钥后关闭 `PasswordAuth`。ttyd 仅 LAN 访问且走 `/bin/login`，没有 TLS；需要加密请用 SSH 隧道，不要把 7681 直接暴露到 WAN。
>
> OpenClash 默认关闭；如果启用，请检查它的 DNS 上游和 IPv6 fallback，确认业务查询确实走你预期的加密链路。

**构建期注入与可追溯（2026-10-09 起）**

- **OpenClash 控制面板密码不再写死在仓库里**：构建时注入。仓库 secret `OPENCLASH_DASH_PASS` 优先，未配置则每次构建随机生成。
  在路由器上查看方式：`uci get openclash.@config[0].dashboard_password`
  **注意：这个密码会随公开镜像一起发布，不是设备级秘密；面板只应 LAN 可达，启用后建议首次登录修改。**
- 每次构建的 release 里附带 **`BUILD_SOURCE.txt`** 和 **`SOURCE_LOCK.txt`**：记录本次固件对应的 AutoBuild-OpenWrt commit、lede / feeds 各源 commit、最终 `.config` 的 sha256；`SOURCE_LOCK.txt` 是最终 target/config 写入后的快照，便于事后核对和回滚。`SOURCE_LOCK.txt` 还记录 `luci-app-filetransfer` / `luci-lib-fs` / `geo2txt` 的来源 commit 和入库 `clash_meta` 的 sha256。
- 发布时除生产 `AutoUpdate` tag 外，还会保留 **`AutoUpdate-<编译时间>`** 日期 tag，并生成 **`versions.json`**（文件名、大小、sha256）；需要回滚时按日期 tag 找旧固件，不要依赖资产名排序。
- 可选 **`REPO_COMMIT`**：在 `build/Lede_source/settings.ini` 填 40 位 commit SHA 可钉住主源码；留空则跟随 `REPO_BRANCH`（默认 master）。
- feeds 和第三方 package 仓默认跟随上游 tip；每次构建会把实际 commit 写进 `SOURCE_LOCK.txt`。每月 1 号 17:00 UTC 定时构建一次，用于跟随上游并检查构建结果。只有 `main` 分支会创建 release / 更新 `AutoUpdate`，测试分支只构建 artifact。
- 固件版本号由 `.github/workflows/compile-openwrt.yml` 的 `FIRMWARE_VER` 按构建日期生成（`RYY.MM.DD`，单一来源）；如需固定版本，只改这一处。
- release 里保留 `*sha256sums*` / `*manifest*` / `*buildinfo*`，可用于校验与包清单核对。

**仓库 secret**

| secret | 用途 | 必填 |
| ---- | ---- | ---- |
| `REPO_TOKEN` | 发布 release / 云端更新（fine-grained PAT；只给目标仓库 `Contents: Read and write`，设置过期时间） | 仅发布链路需要 |
| `FIRMWARE_SIGN_KEY_B64` | `.sha256` 清单的 Ed25519 私钥（base64）；只在 main 的 sign job 使用，build job 不读取 | `REGULAR_UPDATE=true` 时必填 |
| `TELEGRAM_BOT_TOKEN`、`TELEGRAM_CHAT_ID` | 构建通知 | 否 |
| `OPENCLASH_DASH_PASS` | OpenClash 面板密码；会写进镜像，**不是设备级秘密** | 否 |

> secret 只放在 GitHub 仓库 Secret 里，不要写进 README、issue、提交记录或聊天。
>
> `REPO_TOKEN` 建议用 fine-grained PAT，只授权目标仓库的 `Contents: Read and write`；不要用带 admin/workflow 权限的 classic token。
>
> `FIRMWARE_SIGN_KEY_B64` 是固件签名根信任，泄露等于攻击者可以签出被设备接受的固件；仓库管理员权限也要保护好。

**固件签名密钥（`FIRMWARE_SIGN_KEY_B64`）**

`REGULAR_UPDATE=true` 且分支为 `main` 时，工作流会用 Ed25519 给每个 `<固件>.sha256` 清单签名，设备端用固件内置的 `/etc/firmware-signing.pub` 验签。

推荐用下面的方式生成，**不要让私钥出现在终端输出里**：

```sh
umask 077
openssl genpkey -algorithm ED25519 -out fw-signing.pem

# 公钥写入仓库；这是公开文件，必须提交/替换
openssl pkey -in fw-signing.pem -pubout \
  -out build/Lede_source/files/etc/firmware-signing.pub

# 直接把私钥交给 gh，避免 base64 打印到屏幕
base64 -w0 fw-signing.pem | \
  gh secret set FIRMWARE_SIGN_KEY_B64 --repo <owner>/<repo>

rm -f fw-signing.pem
```

如果没有 `gh`，可以在 GitHub Secret 页面手工新建，但不要把 `base64` 输出粘贴到 issue、聊天或日志；终端 scrollback 也要清掉。

**注意：**

- `fw-signing.pem`、`*.key` 不要提交；仓库 `.gitignore` 已覆盖这些文件。
- 公钥 `build/Lede_source/files/etc/firmware-signing.pub` 是公开文件，必须与 secret 配对；workflow 在签名后会回验。
- 轮换密钥后，旧固件设备内置的是旧公钥，会拒收新固件，需要手动刷一次新固件。
- 签名私钥是固件信任根；GitHub Secret 只应给必要管理员访问，构建 job 不读取它，只有 main 的独立 sign job 使用。

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
- 插件源：kenzok8/openwrt-packages + kenzok8/small + vernesong/OpenClash + fw876/helloworld + sbwml/luci-app-mosdns (geo2txt)
- GFW 菜单归类：OpenClash / PassWall / SSR-Plus / ZeroTier / IPSec
- 中文菜单重命名：改密码 / 网盘挂载 / 文件管理 / 端口转发 / 网络加速 等
- x86 镜像类型：
  - `*-squashfs-combined.img.gz`：Legacy / BIOS 启动
  - `*-squashfs-combined-efi.img.gz`：UEFI 启动
- PVE 虚拟平台：UEFI 虚拟机下载 `*-squashfs-combined-efi.img`，BIOS 虚拟机下载 `*-squashfs-combined.img`，使用 `qm importdisk` 导入

**主要插件**

OpenClash / PassWall / SSR-Plus / AdGuard Home / mosdns / OpenList(文件管理, 原 AList) / ZeroTier / ttyd / netdata / Diskman

> AdGuard Home 默认只装 `luci-app-adguardhome` 壳，**不打包核心**。刷完固件后在 LuCI 页面点“更新核心”下载，或手动放入 `/usr/bin/AdGuardHome`；`/etc/AdGuardHome.yaml` 和已下载的核心会被 `keep.d` 保留，升级后还原设置即可。
>
> `firewall.user` 默认无条件把 LAN IPv4/IPv6 的 53 重定向到 `5553`。不使用 AdGuardHome 的，请删除或清空 `build/Lede_source/files/etc/firewall.user` 里的对应规则，否则 DNS 会指向不存在的 `5553`。
>
> OpenClash 的 `clash_meta` 是仓库内置的 x86-64 静态内核，**不会随 OpenClash 上游自动更新**；升级时需同时替换二进制并更新 `build/common/post-feeds.sh` 的 `CLASH_SHA`。

固件页面 Firmware page

![image](https://raw.githubusercontent.com/Lul1a8y/AutoBuild-OpenWrt/main/img/opimg.png)

# 感谢 thank

- [大雕 源码仓库](https://github.com/coolsnowwolf/lede.git)
- [kenzok8 插件源](https://github.com/kenzok8/openwrt-packages)
- [vernesong OpenClash](https://github.com/vernesong/OpenClash)
- [fw876 helloworld](https://github.com/fw876/helloworld)
- [sbwml luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns)
- [P3TERX 自动编译脚本](https://github.com/P3TERX/Actions-OpenWrt)
- [Hyy2001X 定时更新脚本](https://github.com/Hyy2001X/AutoBuild-Actions)
- [gd0772 原版 AutoBuild-OpenWrt](https://github.com/gd0772/AutoBuild-OpenWrt)
