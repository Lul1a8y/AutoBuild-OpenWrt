#!/bin/sh
# router-acceptance.sh — J4125 路由器刷机后验收自检(只读, 不改任何配置)
#
# 用法(在路由器上):
#   scp scripts/router-acceptance.sh root@192.168.50.2:/tmp/ && ssh root@192.168.50.2 sh /tmp/router-acceptance.sh
#   # 或直接在 ttyd / SSH 里: sh /tmp/router-acceptance.sh
#
# 检查项对应 PLAN-openwrt-hardening-6.18.md 的验收清单:
#   四口映射 / EEE 与 igc 健康 / PPPoE 与 MTU/MSS / IPv6 / DNS 链 / 代理分流 / offload / 存储
# 输出 PASS / WARN / FAIL 三态; 退出码 = FAIL 数量(0 = 全通过, WARN 不影响退出码)。
#
# 注意: 全程只读。不碰 uci set / 不重启服务 / 不打印任何密码字段。
# 注意: 本脚本会主动向 www.baidu.com / www.google.com 发起 DNS/HTTP 诊断请求；
# 只用于人工验收，不是固件运行时行为。

FAILN=0
WARNN=0

say()  { printf '%s\n' "$*"; }
head2() { printf '\n===== %s =====\n' "$*"; }
ok()   { printf '  [PASS] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; WARNN=$((WARNN+1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; FAILN=$((FAILN+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 1. 系统信息 ----------
head2 "1. 系统"
say "  内核:   $(uname -r)"
if [ -f /etc/openwrt_release ]; then
  . /etc/openwrt_release 2>/dev/null
  say "  固件:   ${DISTRIB_ID:-?} ${DISTRIB_RELEASE:-?} (${DISTRIB_ARCH:-?})"
fi
say "  uptime: $(uptime 2>/dev/null | sed 's/^ *//')"

# ---------- 2. 网口映射 ----------
head2 "2. 网口映射 (期望 LAN=eth0/eth2/eth3, WAN=eth1)"
if [ -f /etc/board.json ]; then
  if have jsonfilter; then
    LANP="$(jsonfilter -i /etc/board.json -e '@.network.lan.ports[*]' 2>/dev/null | tr '\n' ' ')"
    WANP="$(jsonfilter -i /etc/board.json -e '@.network.wan.ports[*]' 2>/dev/null | tr '\n' ' ')"
    say "  board.json: LAN=[${LANP% }] WAN=[${WANP% }]"
    case "$(echo $LANP)" in "eth0 eth2 eth3") ok "board.json LAN 端口符合预期" ;; *) bad "board.json LAN 端口不符: $LANP" ;; esac
    case "$(echo $WANP)" in "eth1") ok "board.json WAN 端口符合预期" ;; *) bad "board.json WAN 端口不符: $WANP" ;; esac
  else
    warn "jsonfilter 不存在, 跳过 board.json 结构化校验"
  fi
else
  warn "没有 /etc/board.json(config_generate 只把 eth0 加进 br-lan)"
fi
say "  uci lan.ports:   $(uci -q get network.lan.ports 2>/dev/null || echo '(未设置)')"
say "  uci wan.device:  $(uci -q get network.wan.device 2>/dev/null || echo '(未设置)')"
BR="$(ls /sys/class/net/br-lan/brif 2>/dev/null | tr '\n' ' ')"
[ -n "$BR" ] && say "  br-lan 实成员:   ${BR% }" || warn "br-lan 无成员或不存在"

for i in eth0 eth1 eth2 eth3; do
  [ -d "/sys/class/net/$i" ] || { bad "$i 不存在(网口未识别: 检查 i225 驱动 / 固件网卡名)"; continue; }
  CAR="$(cat /sys/class/net/$i/carrier 2>/dev/null)"
  SPD="$(cat /sys/class/net/$i/speed 2>/dev/null)"
  DUP="$(cat /sys/class/net/$i/duplex 2>/dev/null)"
  INBR="yes"; [ -e "/sys/class/net/br-lan/brif/$i" ] || INBR="no"
  if [ "$CAR" = "1" ]; then
    ok "$i link up ${SPD:-?}Mb ${DUP:-?} full-duplex, br-lan成员=$INBR"
    [ "$SPD" = "2500" ] || warn "$i 速率 ${SPD:-?}Mb ≠ 2500Mb(线材/对端协商)"
  else
    say "  [----] $i 无 link(carrier=$CAR) — 未插线或对端关闭"
  fi
done

# ---------- 3. EEE ----------
head2 "3. EEE (i225 链路抖动缓解)"
if have ethtool; then
  for i in eth0 eth1 eth2 eth3; do
    [ -d "/sys/class/net/$i" ] || continue
    EEE="$(ethtool --show-eee "$i" 2>/dev/null | grep -i '^EEE status' | sed 's/^ *//')"
    [ -n "$EEE" ] && say "  $i: $EEE" || say "  $i: (网卡/驱动不支持或未取到)"
  done
  case "$(ethtool --show-eee eth0 2>/dev/null | grep -i '^EEE status')" in
    *disabled*) ok "eth0 EEE 已关闭" ;;
    *enabled*)  warn "eth0 EEE 仍 enabled(rc.local 的 ethtool 循环是否未生效?)" ;;
  esac
else
  warn "ethtool 不存在, 跳过 EEE 检查"
fi

# ---------- 4. igc 健康(eth0 flap 取证) ----------
head2 "4. 网卡健康 (igc 错误/复位计数)"
if have dmesg; then
  NM="$(dmesg 2>/dev/null | grep -ci 'igc')"
  NL="$(dmesg 2>/dev/null | grep -ciE 'igc.*(link is down|NIC Link is Down|reset)')"
  say "  dmesg 中 igc 行数: $NM, 含 link down/reset: $NL"
  [ "$NL" -le 4 ] && ok "本次开机 link down/reset 次数正常(≤4)" || warn "link down/reset 次数偏多($NL) —— 抓 flap 证据: dmesg | grep -i igc"
fi
if have ethtool; then
  for i in eth0 eth1; do
    [ -d "/sys/class/net/$i" ] || continue
    ERRS="$(ethtool -S "$i" 2>/dev/null | grep -iE '^( +)?(rx_errors|tx_errors|rx_dropped|tx_dropped|rx_missed|rx_over_errors|tx_timeout)' | tr -s ' ' | tr '\n' ';')"
    [ -n "$ERRS" ] && say "  $i 计数: $ERRS" || say "  $i: 无错误计数输出"
  done
fi

# ---------- 5. WAN / PPPoE / MTU ----------
head2 "5. WAN / PPPoE / MTU / MSS"
if have ubus; then
  if ubus list network.interface.wan >/dev/null 2>&1; then
    ST="$(ubus call network.interface.wan status 2>/dev/null)"
    case "$ST" in
      *'"up": true'*) ok "WAN 接口 up" ;;
      *) bad "WAN 接口未 up —— 看 logread | grep -i pppoe" ;;
    esac
    V4="$(echo "$ST" | jsonfilter -e '@.ipv4-address[0].address' 2>/dev/null)"
    [ -n "$V4" ] && say "  WAN IPv4: $V4  uptime: $(echo "$ST" | jsonfilter -e '@.uptime' 2>/dev/null)s"
  fi
fi
PPPD="$(ip -4 addr show 2>/dev/null | awk '/pppoe-wan|pppoe/{print}')"
[ -n "$PPPD" ] && say "  $(echo "$PPPD" | tr -s ' ')" || warn "未见 pppoe-wan 地址"
if have ip; then
  MTU="$(ip link show 2>/dev/null | awk '/pppoe-wan/{for(i=1;i<=NF;i++) if($i=="mtu") print $(i+1)}')"
  [ -n "$MTU" ] && { say "  pppoe-wan MTU: $MTU"; [ "$MTU" -ge 1492 ] && ok "MTU ≥1492" || warn "MTU $MTU <1492(PPPoE 建议 1492)"; }
  PMTU="$(ip route get 1.1.1.1 2>/dev/null | tr -s ' ')"
  [ -n "$PMTU" ] && say "  route: $PMTU"
fi
MSS="$( (iptables -t mangle -S 2>/dev/null; nft list ruleset 2>/dev/null) | grep -ci 'tcp option maxseg size' )"
[ "${MSS:-0}" -ge 1 ] && ok "存在 MSS clamp 规则($MSS 条)" || warn "未见 MSS clamp 规则(部分透明代理/PPPoe 场景需要)"

# ---------- 6. IPv6 ----------
head2 "6. IPv6"
if have ip; then
  V6="$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/{print $2}' | head -4 | tr '\n' ' ')"
  [ -n "$V6" ] && ok "全局 IPv6: ${V6% }" || warn "无全局 IPv6 地址(若不需要可忽略)"
  ip -6 route show default 2>/dev/null | head -2 | sed 's/^/  default: /'
fi

# ---------- 7. DNS 链 ----------
head2 "7. DNS 链 (dnsmasq:53 → AGH → mosdns:5335)"
L53="$( (netstat -ln 2>/dev/null || ss -ln 2>/dev/null) | grep -c ':53 ' )"
[ "$L53" -ge 1 ] && ok "53 端口有监听(dnsmasq 门面)" || bad "53 无监听 —— DNS 全断"
ADDM="$(uci -q get dhcp.@dnsmasq[0].addnmount 2>/dev/null)"
if [ -n "$ADDM" ]; then
  if [ -d "$ADDM" ]; then ok "addnmount 目录存在: $ADDM"
  else bad "addnmount 指向不存在的目录 $ADDM —— dnsmasq 会崩(已知故障: mkdir -p 或 uci delete)"; fi
else
  ok "未设置 addnmount(无该故障面)"
fi
pgrep -f AdGuardHome >/dev/null 2>&1 && ok "AdGuardHome 进程在" || warn "AdGuardHome 进程不在"
pgrep -f mosdns >/dev/null 2>&1 && ok "mosdns 进程在" || warn "mosdns 进程不在"
CRASH="$(logread 2>/dev/null | grep -ciE 'dnsmasq.*(crash|segfault|exited)')"
[ "${CRASH:-0}" = "0" ] && ok "本次开机无 dnsmasq 崩溃记录" || warn "logread 有 $CRASH 条 dnsmasq 崩溃记录"
# 解析测试
if have nslookup; then
  nslookup www.baidu.com 127.0.0.1 >/dev/null 2>&1 && ok "本机解析(baidu) 正常" || bad "本机解析失败"
  nslookup www.google.com 127.0.0.1 >/dev/null 2>&1 && ok "本机解析(google) 正常(分流/代理解析可取)" || warn "google 解析失败(可能未走代理 DNS)"
elif have ping; then
  ping -c1 -W3 -q www.baidu.com >/dev/null 2>&1 && ok "DNS 可用(ping baidu 解析成功)" || bad "ping 解析失败"
fi

# ---------- 8. 代理 ----------
head2 "8. 透明代理 (PassWall 本机代理)"
PW="$(uci -q get passwall.@global[0].enabled 2>/dev/null)"
[ "$PW" = "1" ] && ok "PassWall enabled=1" || warn "PassWall enabled=${PW:-未配置}"
TCPMODE="$(uci -q get passwall.@global[0].tcp_node 2>/dev/null)"
[ -n "$TCPMODE" ] && say "  TCP 节点已选(值不打印)"
LOCAL="$(uci -q get passwall.@global[0].localhost_proxy 2>/dev/null)"
say "  本机代理(localhost_proxy): ${LOCAL:-未设置}"
if have curl; then
  G="$(curl -s -m 10 -o /dev/null -w '%{http_code}' https://www.google.com 2>/dev/null)"
  B="$(curl -s -m 10 -o /dev/null -w '%{http_code}' https://www.baidu.com 2>/dev/null)"
  case "$G" in
    200|301|302) ok "被墙站点可达(google HTTP $G) → 本机代理生效" ;;
    *)           warn "google HTTP $G(本机代理可能未生效/节点不可用)" ;;
  esac
  case "$B" in
    200) ok "国内站点直连正常(baidu HTTP $B)" ;;
    *)   warn "baidu HTTP $B" ;;
  esac
fi
logread 2>/dev/null | grep -c '【路由器本机】' | sed 's/^/  PassWall 本机代理日志条数: /'

# ---------- 9. 转发 / offload ----------
head2 "9. 转发性能相关"
FO="$(uci -q show firewall 2>/dev/null | grep -E 'flow_offloading|flow_offloading_hw' | tr '\n' ' ')"
say "  ${FO:-未配置 flow offloading}"
[ -f /proc/sys/net/netfilter/nf_conntrack_count ] && say "  conntrack: $(cat /proc/sys/net/netfilter/nf_conntrack_count)/$(cat /proc/sys/net/netfilter/nf_conntrack_max)"
say "  NAT 规则数: $(iptables -t nat -S 2>/dev/null | wc -l)"

# ---------- 10. 存储 ----------
head2 "10. 存储"
df -h /overlay /tmp 2>/dev/null | sed 's/^/  /'
blk="$(lsblk 2>/dev/null | head -5)"
[ -n "$blk" ] && say "$blk" || warn "无 lsblk(不影响路由功能)"

# ---------- 11. 配置一致性 / 暴露面 ----------
head2 "11. 配置一致性 / 暴露面"
if uci -q show firewall 2>/dev/null | grep -q "path='/etc/firewall.user'"; then
  ok "firewall.user 的 fw4 include 存在"
else
  warn "firewall.user 的 fw4 include 不存在(新刷机 DNS 劫持不会生效)"
fi
if iptables -t nat -S PREROUTING 2>/dev/null | grep -q -- '--dport 53.*5553'; then
  ok "LAN 53→5553 劫持规则存在"
else
  warn "未见 53→5553 劫持规则"
fi
ADH_REDIRECT="$(uci -q get AdGuardHome.AdGuardHome.redirect 2>/dev/null)"
say "  AdGuardHome.redirect=${ADH_REDIRECT:-未配置}"
for p in 12306 7681 19999; do
  if (netstat -ln 2>/dev/null || ss -ln 2>/dev/null) | grep -q ":$p "; then
    say "  [INFO] 端口 $p 在监听(应仅 LAN 可达)"
  fi
done
if grep -q 'check_signature' /etc/opkg.conf 2>/dev/null; then
  ok "opkg check_signature 已启用"
else
  warn "opkg check_signature 未启用"
fi
say "  wan.ipv6=$(uci -q get network.wan.ipv6 2>/dev/null || echo 未设置)  wan6.device=$(uci -q get network.wan6.device 2>/dev/null || echo 未设置)"

# ---------- 11. 暴露面/配置一致性 ----------
WANPROTO="$(uci -q get network.wan.proto 2>/dev/null)"
WAN6PROTO="$(uci -q get network.wan6.proto 2>/dev/null)"
WAN6DEV="$(uci -q get network.wan6.device 2>/dev/null)"
say "  WAN proto: ${WANPROTO:-?}; wan6: ${WAN6PROTO:-未配置} dev=${WAN6DEV:-无}"
if [ "$WANPROTO" = "pppoe" ] && [ -n "$WAN6DEV" ] && [ "$WAN6DEV" != "@wan" ]; then
  warn "wan proto=pppoe 但 wan6.device=$WAN6DEV（建议 @wan 或删除 wan6）"
fi

# ---------- 摘要 ----------
head2 "摘要"
say "  FAIL=$FAILN  WARN=$WARNN"
if [ "$FAILN" -eq 0 ]; then
  say "  未发现硬失败项。WARN 项按需人工确认。"
else
  say "  有 $FAILN 项硬失败, 先处理 FAIL 再看 WARN。"
fi
say ""
say "  持续转发取证(建议 24-48h 后再跑一次, 对比计数):"
say "    dmesg | grep -i igc | tail -30"
say "    ethtool -S eth0 | grep -iE 'err|drop|reset'"
exit "$FAILN"
