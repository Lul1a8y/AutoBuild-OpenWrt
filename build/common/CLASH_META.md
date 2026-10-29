# clash_meta 来源记录

`build/Lede_source/files/etc/openclash/core/clash_meta` 是随固件以 root 执行的预编译内核。

| 项目 | 值 |
|---|---|
| 大小 | 7.4 MB |
| 架构 | x86-64，ELF，静态链接，UPX 加壳 |
| sha256 | `459c92959289214a8f8d11abea02057382048bc1add8574f04f1223b6095802a` |
| 来源 | 预编译二进制；仓库未记录确切的 OpenClash/mihomo 上游 tag |
| 校验 | `build/common/post-feeds.sh` 的 `CLASH_SHA` 在构建时强制比对 |

## 更新规则

1. 只从可信的 OpenClash/mihomo 发布页获取对应 x86-64 版本。
2. 记录下载 URL、上游 tag/commit、下载日期和原始压缩包的 sha256。
3. 同时更新本文件的 sha256 和 `post-feeds.sh` 的 `CLASH_SHA`，不要只改其中一个。
4. 不要把“哈希写在同一个仓库”当成来源证明：有仓库写权限的人可以同时替换二进制和哈希。
