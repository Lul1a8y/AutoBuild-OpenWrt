#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate for Openwrt

Version=V6.5

# 2026-10-31(O5): /etc/CLOUD_Name 会被后续逻辑读取; 只接受安全字符, 防止 JSON 里的
# 资产名把换行/重定向等带进这个文件。正常升级路径会调用; -h 不写。
write_cloud_name() {
	[ -n "$1" ] || return 0
	if [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; then
		echo "$1" > /etc/CLOUD_Name
	else
		echo "!! 固件名含非法字符, 跳过写 /etc/CLOUD_Name: $1" >&2
		return 1
	fi
}

# 2026-10-31(O9): 资产名里的时间戳是 12 位数字, 但整串按字典序排序并不等于
# 版本顺序(前缀/启动类型/哈希都会参与比较)。先抽出时间戳做数值排序, 再输出
# 原资产名; 没有时间戳时退回原来的字典序, 兼容非本仓库命名的资产。
select_latest_firmware() {
	local data selected
	data="$(cat)"
	selected="$(printf '%s\n' "${data}" | awk -F- '
		{
			for (i = 1; i <= NF; i++) {
				if (length($i) == 12 && $i ~ /^[0-9]+$/) {
					print $i "\t" $0
					break
				}
			}
		}' | sort -n | tail -n 1 | cut -f2-)"
	[ -n "${selected}" ] || selected="$(printf '%s\n' "${data}" | sort | tail -n 1)"
	printf '%s\n' "${selected}"
}

Shell_Helper() {
echo
echo

echo -e "${Yellow}命令用途：

bash /bin/AutoUpdate.sh				[保留配置更新]
bash /bin/AutoUpdate.sh	-n			[不保留配置更新]
bash /bin/AutoUpdate.sh	-f			[强制更新固件(保留配置)]
bash /bin/AutoUpdate.sh	-g			[已停用: 18.06/19.07/21.02 旧通道均已 EOL]
bash /bin/AutoUpdate.sh	-c			[更换Github地址]
bash /bin/AutoUpdate.sh	-t			[执行测试模式(只运行,不安装,查看更新固件操作流程)]
bash /bin/AutoUpdate.sh	-h			[列出帮助信息]
${White}"

echo -e "${Purple}
===============================================================================================
${White}"
echo
# 2026-11-01(O10): -h/-l 和非法参数只读本地缓存, 不访问 GitHub, 也不创建
# /etc/CLOUD_Name、/etc/openwrt_ver。帮助页没有缓存时显示“未缓存”, 由正常升级写入。
if [[ -f /etc/CLOUD_Name ]]; then
	export CLOUD_Name="$(egrep -o "${Egrep_Firmware}-[0-9]+${BOOT_Type}-[a-zA-Z0-9]+${Firmware_SFX}" /etc/CLOUD_Name | select_latest_firmware)" > /dev/null 2>&1
else
	export CLOUD_Name="未缓存"
fi
[[ -n "${CLOUD_Name}" ]] || export CLOUD_Name="未缓存"
echo -e "${Green}详细参数：

/overlay 可用:					${Overlay_Available}
/tmp 可用:					${TMP_Available}M
固件下载位置:					${Download_Path}
当前设备名称:					${CURRENT_Device}
固件上的名称:					${DEFAULT_Device}
当前固件版本:					${CURRENT_Version}
Github 地址:					${Github}
解析 API 地址:					${Github_Tags}
固件下载地址:					${Github_Release}
更新运行日志:					${AutoUpdate_Log_Path}/AutoUpdate.log
固件作者:					${Author}
作者仓库:					${CangKu}
固件名称:					${CLOUD_Name}
固件格式:					${EFI_Mode}${Firmware_SFX}
${White}"
exit 0
}
White="\033[0;37m"
Yellow="\033[0;33m"
Red="\033[1;91m"
Blue="\033[0;94m"
BLUEB="\033[1;94m"
BCyan="\033[1;36m"
Grey="\033[1;34m"
Green="\033[0;92m"
Purple="\033[1;95m"
[ -f /bin/openwrt_info ] && {
	chmod +x /bin/openwrt_info
	source /bin/openwrt_info
} || {
	echo -e "\n${Red}未检测到更新插件所需文件,无法运行更新程序!${White}"
	echo
	exit 1
}
export Input_Option=$1
export Input_Other=$2
export Apidz="${Github##*com/}"
export Author="${Apidz%/*}"
export CangKu="${Apidz##*/}"
export Github_Tags="https://api.github.com/repos/${Apidz}/releases/tags/AutoUpdate"
export Github_Tagstwo="${Github}/releases/download/AutoUpdate/Github_Tags"
export Kernel="$(egrep -o "[0-9]+\.[0-9]+\.[0-9]+" /usr/lib/opkg/info/kernel.control)"
export Overlay_Available="$(df -h | grep ":/overlay" | awk '{print $4}' | awk 'NR==1')"
# 2026-10-31(O15): /tmp 是 1777, 固定目录名可被本地低权用户预创建为符号链接,
# 让 root 的下载/校验/备份写到别处。改为 root 私有 0700 目录, 且拒绝符号链接/非 root 所有者。
# 2026-10-31(O16): 先拿锁再清理下载目录, 避免第二个实例在拿锁前删掉第一个实例的固件/备份。
case "${Download_Path}" in
	*[[:space:]]*) echo "!! Download_Path 含空白, 拒绝使用: ${Download_Path}" >&2; exit 1 ;;
	/tmp/*) ;;
	*) Download_Path="/tmp/Downloads" ;;
esac
# 只接受 /tmp 下的单级目录; 规范尾随斜杠, 拒绝 /tmp 本身、.. 和嵌套路径。
Download_Path="${Download_Path%/}"
case "${Download_Path}" in
	/tmp) echo "!! Download_Path 不能是 /tmp 本身" >&2; exit 1 ;;
esac
case "${Download_Path#/tmp/}" in
	""|.|..|*/*) echo "!! Download_Path 必须是 /tmp 下的单级目录: ${Download_Path}" >&2; exit 1 ;;
esac
export Download_Tags="${Download_Path}/Github_Tags"
export TMP_Available="$(df -m | grep "/tmp" | awk '{print $4}' | awk 'NR==1' | awk -F. '{print $1}')"
export AutoUpdate_Log_Path="/tmp"
# 2026-11-01(O10): 帮助必须在拿锁、清理下载目录之前返回; 只读本地信息。
case ${DEFAULT_Device} in
x86-64)
	[ -d /sys/firmware/efi ] && {
		export BOOT_Type="-UEFI"
		export EFI_Mode="UEFI"
	} || {
		export BOOT_Type="-Legacy"
		export EFI_Mode="Legacy"
	}
	export CURRENT_Device="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
	export Firmware_SFX=".${Firmware_Type}"
	[[ -z "${Firmware_Type}" ]] && export Firmware_SFX=".img.gz"
;;
*)
	export CURRENT_Device="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
	export Firmware_SFX=".${Firmware_Type}"
	export BOOT_Type="-Sysupg"
	export EFI_Mode=""
	[[ -z "${Firmware_Type}" ]] && export Firmware_SFX=".bin"
esac
export CURRENT_Ver="${CURRENT_Version}${BOOT_Type}"
case ${Input_Option} in
	-h|-H|-l|-L)
		Shell_Helper
	;;
esac
# 2026-10-31(O15): 手动通道原来没有锁。与包内 /usr/bin/AutoUpdate 共用同一个锁文件,
# 避免 cron 升级与手动执行同时跑 sysupgrade -b/-f。
umask 077
if command -v flock >/dev/null 2>&1; then
	exec 9>>"/tmp/autoupgrade.lock" || { echo "!! 无法打开升级锁" >&2; exit 1; }
	flock -n 9 || { echo "!! 已有升级任务在运行, 退出" >&2; exit 1; }
else
	LOCK_DIR="/tmp/autoupgrade.lock.d"
	mkdir "${LOCK_DIR}" 2>/dev/null || { echo "!! 已有升级任务在运行, 退出" >&2; exit 1; }
	trap 'rmdir "${LOCK_DIR}" 2>/dev/null || true' EXIT
fi
# 拿到锁后才允许删除/重建下载目录; 符号链接检查必须在 rm 之前。
[ -L "${Download_Path}" ] && { echo "!! ${Download_Path} 是符号链接, 拒绝使用" >&2; exit 1; }
if [ -e "${Download_Path}" ] && [ ! -d "${Download_Path}" ]; then
	echo "!! ${Download_Path} 不是目录, 拒绝使用" >&2
	exit 1
fi
rm -rf "${Download_Path}"
mkdir -p -m 700 "${Download_Path}" || { echo "!! 无法创建私有下载目录 ${Download_Path}" >&2; exit 1; }
[ -O "${Download_Path}" ] && [ ! -L "${Download_Path}" ] || { echo "!! ${Download_Path} 所有者异常" >&2; exit 1; }
opkg list | awk '{print $1}' > "${Download_Path}/Installed_PKG_List"
export PKG_List="${Download_Path}/Installed_PKG_List"

GET_PID() {
	local Result
	while [[ $1 ]];do
		Result=$(busybox ps | grep "$1" | grep -v "grep" | awk '{print $1}' | awk 'NR==1')
		[[ -n ${Result} ]] && echo ${Result}
	shift
	done
}
TIME() {
	local Color
	[[ -z $1 ]] && {
		echo -ne "\n${Grey}[$(date "+%H:%M:%S")]${White} "
	} || {
	case $1 in
		r) Color="${Red}";;
		g) Color="${Green}";;
		b) Color="${Blue}";;
		B) Color="${BLUEB}";;
		y) Color="${Yellow}";;
		h) Color="${BCyan}";;
		z) Color="${Purple}";;
		x) Color="${Grey}";;
	esac
		[[ $# -lt 2 ]] && {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} $1"
			LOGGER $1
		} || {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} ${Color}$2${White}"
			LOGGER $2
		}
	}
}

LOGGER() {
	[[ ! -d ${AutoUpdate_Log_Path} ]] && mkdir -p ${AutoUpdate_Log_Path}
	[[ ! -f ${AutoUpdate_Log_Path}/AutoUpdate.log ]] && touch ${AutoUpdate_Log_Path}/AutoUpdate.log
	echo "[$(date "+%Y-%m-%d-%H:%M:%S")] [$(GET_PID AutoUpdate.sh)] $*" >> ${AutoUpdate_Log_Path}/AutoUpdate.log
}
cd /etc
clear && echo "Openwrt-AutoUpdate Script ${Version}"
echo
if [[ -z "${Input_Option}" ]];then
	export Upgrade_Options="sysupgrade -q"
	export Update_Mode=1
	TIME h "执行: 保留配置更新固件[静默模式]"
else
	case ${Input_Option} in
	-t | -n | -f | -u | -N | -s | -w)
		case ${Input_Option} in
		-t)
			export Input_Other="-t"
			TIME h "执行: 测试模式"
			TIME z "测试模式(只运行,不安装,查看更新固件操作流程是否正确)"
		;;
		-w)
			export Input_Other="-w"
		;;
		-n | -N)
			export Upgrade_Options="sysupgrade -n"
			TIME h "执行: 更新固件(不保留配置)"
		;;
		-s)
			# -s 的语义是强制更新, 同时跳过版本比较交互; 与 -f 保持一致。
			export Force_Update=1
			export Upgrade_Options="sysupgrade -F -n"
			TIME h "执行: 强制更新固件(不保留配置)"
		;;
		-u)
			export AutoUpdate_Mode=1
			export Upgrade_Options="sysupgrade -q"
		;;
		-f)
			# 2026-10-24: 原来 case 里列了 -f 却没有分支, Upgrade_Options 为空,
			# 最后变成直接执行 .img.gz 文件(bash: cannot execute binary file)。
			# 2026-10-29: -f 的语义是强制更新, 同时跳过版本比较的交互询问。
			export Force_Update=1
			export Upgrade_Options="sysupgrade -F"
			TIME h "执行: 强制更新固件(保留配置)"
		;;
		esac
	;;
	-c)
			source /bin/openwrt_info
			TIME h "执行：更换[Github地址]操作"
			TIME y "地址格式：https://github.com/帐号/仓库"
			TIME z  "正确地址示例：https://github.com/Lul1a8y/AutoBuild-OpenWrt"
			TIME h  "现在所用地址为：${Github}"
			echo
			read -p "请输入新的Github地址：" Input_Other
			Input_Other="${Input_Other:-"$Github"}"
			[[ "${Input_Other}" =~ ^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || {
				TIME r "地址格式不合法,只接受 https://github.com/<帐号>/<仓库>"
				echo
				exit 1
			}
			Github_uci=$(uci get autoupdate.@login[0].github 2>/dev/null)
			if [[ -n "${Github_uci}" ]] && [[ "${Github_uci}" != "${Input_Other}" ]]; then
				uci set "autoupdate.@login[0].github=${Input_Other}" || {
					TIME r "UCI 设置失败, 未修改 Github 地址"; exit 1
				}
				uci commit autoupdate || {
					TIME r "UCI 提交失败, Github 地址可能未持久化"; exit 1
				}
				TIME y "Github 地址已更换为: ${Input_Other}"
				TIME y "UCI 设置已更新!"
				echo
			fi
			Input_Other="${Input_Other:-"$Github"}"
			[[ "${Github}" != "${Input_Other}" ]] && {
				# 2026-10-29: URL 里的 . 在 sed 正则是通配符; 先转义再替换。
				# 替换串里的 & 和 \ 也转义, 避免被 sed 当成反向引用。
				Github_escaped="$(printf '%s' "${Github}" | sed 's/\./\\./g')"
				Safe_Other="$(printf '%s' "${Input_Other}" | sed 's/[\\&]/\\&/g')"
				sed -i "s?${Github_escaped}?${Safe_Other}?g" /bin/openwrt_info || {
					TIME r "/bin/openwrt_info 写入失败, Github 地址未更新"; exit 1
				}
				unset Github_escaped Safe_Other
				grep -Fq "${Input_Other}" /bin/openwrt_info || {
					TIME r "/bin/openwrt_info 未写入新地址"; exit 1
				}
				# 2026-10-27: /bin/openwrt_info 只有本脚本(手动升级通道)读; LuCI 升级页和
				# /usr/bin/AutoUpdate 读的是 /etc/openwrt_update 里的 GITHUB_LINK。
				# 以前只改 openwrt_info, 换完仓库会出现"LuCI 查新仓库、固件仍从旧仓库下"的双源。
				if [ -f /etc/openwrt_update ]; then
					Safe_URL="$(printf '%s' "${Input_Other}" | sed 's/[\\&]/\\&/g')"
					sed -i "s?^GITHUB_LINK=.*?GITHUB_LINK=\"${Safe_URL}\"?" /etc/openwrt_update
					unset Safe_URL
					# 2026-10-27: 原来失败只打印提示, 随后 exit 0 —— 同步失败也报成功。
					if grep -q "^GITHUB_LINK=\"${Input_Other}\"$" /etc/openwrt_update; then
						TIME y "/etc/openwrt_update 的 GITHUB_LINK 已同步"
					else
						TIME r "/etc/openwrt_update 同步失败, LuCI 升级页仍指向旧仓库"
						echo
						exit 1
					fi
				fi
				unset Input_Other
				exit 0
			} || {
				TIME g "INPUT: ${Input_Other}"
				TIME r "输入的 Github 地址相同,无需修改!"
				echo
				exit 1
			}
	;;
	-g | -G)
		# 18.06/19.07/21.02 通道均已 EOL; 不再调用 replace.sh, 与帮助文本保持一致。
		TIME r "旧通道转换(-g)已停用: 18.06/19.07/21.02 均已 EOL, 请手动刷入当前固件。"
		exit 1
	;;
	*)
		echo -e "\nERROR INPUT: [$*]"
		Shell_Helper
	;;
	esac
fi
# 2026-11-01(O10): -h/-c/-g/非法参数已在 case 内退出; 只有实际升级流程才写
# /etc/openwrt_ver, 帮助不会因为新机器上文件缺失而污染 overlay。
# 2026-10-29: 只有内容变化时才写, 避免每次手动/定时运行都写 overlay。
OPENWRT_VER_CONTENT="$(printf 'CURRENT_Version=%s\n\nCURRENT_Model=%s%s\n\nNEI_Luci=%s - %s\n' \
	"${CURRENT_Version}" "${EFI_Mode}" "${Firmware_SFX}" "${Kernel}" "${Luci_Edition}")"
if [ ! -f /etc/openwrt_ver ] || [ "$(cat /etc/openwrt_ver 2>/dev/null)" != "${OPENWRT_VER_CONTENT}" ]; then
	printf '%s\n' "${OPENWRT_VER_CONTENT}" > /etc/openwrt_ver
fi
unset OPENWRT_VER_CONTENT
[[ -z ${CURRENT_Version} ]] && TIME r "本地固件版本获取失败,请检查/bin/openwrt_info文件的值!" && exit 1
[[ -z ${Github} ]] && TIME r "Github地址获取失败,请检查/bin/openwrt_info文件的值!" && exit 1
TIME g "正在获取云端固件版本信息..."
[ -d "${Download_Path}" ] || mkdir -p "${Download_Path}"
wget -q --timeout=30 --tries=1 "${Github_Tags}" -O "${Download_Tags}" > /dev/null 2>&1
if [[ $? -ne 0 ]];then
	wget -q --timeout=60 --tries=3 "${Github_Tags}" -O "${Download_Path}/Github_Tags" > /dev/null 2>&1
	if [[ $? -ne 0 ]];then
		TIME y "GitHub API 获取失败, 尝试 release 资产 Github_Tags..."
		wget -q --timeout=60 --tries=3 "${Github_Tagstwo}" -O "${Download_Tags}" > /dev/null 2>&1
		if [[ $? -ne 0 ]];then
			TIME r "获取固件版本信息失败,请检测网络,或者您更改的Github地址为无效地址,或者您的仓库是私库,或者发布已被删除!"
			echo
			exit 1
		fi
	fi
fi
TIME g "正在比对云端固件和本地安装固件版本..."
export CLOUD_Firmware="$(egrep -o "${Egrep_Firmware}-[0-9]+${BOOT_Type}-[a-zA-Z0-9]+${Firmware_SFX}" "${Download_Tags}" | select_latest_firmware)"
export CLOUD_sion="$(echo "${CLOUD_Firmware}" | egrep -o "${REPO_Name}-${DEFAULT_Device}-[0-9]+")"
export CLOUD_Version="$(echo "${CLOUD_Firmware}" | egrep -o "${REPO_Name}-${DEFAULT_Device}-[0-9]+${BOOT_Type}")"
[[ -z "${CLOUD_Version}" ]] && {
	TIME r "比对固件版本失败!"
	exit 1
}
[[ "${Input_Other}" == "-w" ]] && {
	echo -e "\nCLOUD_Version=${CLOUD_sion}" > /tmp/Version_Tags
	echo -e "\nCURRENT_Version=${CURRENT_Version}" >> /tmp/Version_Tags
	exit 0
}
export Firmware_Name="$(echo "${CLOUD_Firmware}" | egrep -o "${Egrep_Firmware}-[0-9]+${BOOT_Type}-[a-zA-Z0-9]+")"
export Firmware="${CLOUD_Firmware}"
# 2026-10-31(O5): 资产名来自 release JSON, 后面会参与 wget -O / md5sum / chmod / sysupgrade。
# egrep 已经限制了字符集, 这里再做一次显式白名单: 不在本固件命名空间, 或含 . / 之外字符, 直接中止。
[[ -n "${Firmware}" ]] || { TIME r "云端固件名为空, 已中止"; echo; exit 1; }
case "${Firmware}" in
	"${Egrep_Firmware}-"*"${Firmware_SFX}") ;;
	*) TIME r "云端固件名不在预期命名空间: ${Firmware}"; echo; exit 1 ;;
esac
if ! [[ "${Firmware}" =~ ^[A-Za-z0-9._-]+$ ]]; then
	TIME r "云端固件名含非法字符, 已中止: ${Firmware}"; echo; exit 1
fi
export CLOUD_Name="$(egrep -o "${LUCI_Name}-${CLOUD_sion}${BOOT_Type}-[a-zA-Z0-9]+${Firmware_SFX}" "${Download_Tags}" | select_latest_firmware)"
# 2026-10-31(O10): -t 只做流程演练, 不应把云端资产名落盘到 /etc/CLOUD_Name。
if [[ "${Input_Other}" != "-t" ]]; then
	write_cloud_name "${CLOUD_Name}" || CLOUD_Name=""
fi
# 2026-10-27: 原来用 grep -n "${Firmware}" 取最后一行再回退 4 行, 按位置猜体积。
# GitHub API 给每个资产加了 "digest" 字段后资产在 JSON 里的行数变了: tail -1 命中
# 下载地址行, X-4 落到 "digest" 行 -> 体积恒为 0, 空间检查形同虚设(日志还打印 0M)。
CLOUD_Firmware_Size="$(jq -r --arg n "${Firmware}" '[.assets[]|select(.name==$n)|.size][0]' "${Download_Tags}" 2>/dev/null)"
[[ "${CLOUD_Firmware_Size}" =~ ^[0-9]+$ ]] || CLOUD_Firmware_Size=0
if [[ "${CLOUD_Firmware_Size}" -gt 0 ]]; then
	CLOUD_Firmware_Size=$(( (CLOUD_Firmware_Size + 1048575) / 1048576 ))
	# 2026-10-31(O11): 升级前还要 sysupgrade -b 写备份; keep.d 里含 36MB 的
	# /usr/bin/AdGuardHome, 旧检查只算镜像大小。多留 64MB, 避免下载完才发现备份写不下。
	CLOUD_Firmware_Size=$(( CLOUD_Firmware_Size + 64 ))
else
	TIME g "未能从 API 取得固件体积, 跳过 tmp 空间检查"
fi
echo -e "\n本地版本：${CURRENT_Ver}"
echo "云端版本：${CLOUD_Version}"
[[ "${TMP_Available}" -lt "${CLOUD_Firmware_Size}" ]] && {
	TIME g "tmp 剩余空间: ${TMP_Available}M"
	TIME r "tmp空间不足[${CLOUD_Firmware_Size}M],不够下载固件所需,请清理tmp空间或者增加运行内存!"
	echo
	exit 1
}
# 2026-10-21: 版本比较改成只比末尾的时间戳数字。
# 复核结论: 原写法 [[ "${CURRENT_Version}" -gt "${CLOUD_Version}" ]] 在 bash 下方向其实是对的 ——
# 两边都被算术展开成 "-(64+时间戳)", 负数把大小关系又翻了回来, 所以 "gt 成立" 恰好等于
# "云端更新", 文案也对得上, 不存在"静默降级"(审计第 5 条是误报)。
# 真正的隐患: 换成 sh/ash 跑会报 out of range, 三个分支全不进, 直接落到下载+sysupgrade;
# 版本串前缀一改(lede→immortalwrt)负数大小也会乱。故只取末尾数字, 显式三分支, 解析失败即中止。
# 2026-10-24: x86 的 CLOUD_Version 带尾部 "-UEFI"/"-Legacy", egrep -o "[0-9]+$" 得到空串,
# 于是下面恒触发"版本号解析失败"直接退出 —— 手动升级通道(bash /bin/AutoUpdate.sh)全挂。
# 改用 CLOUD_sion(不含启动类型后缀)取时间戳, 再兜底从整串里抽最长数字段。
Cur_Num="$(echo "${CURRENT_Version}" | egrep -o "[0-9]+$")"
Cloud_Num="$(echo "${CLOUD_sion}" | egrep -o "[0-9]+$")"
[ -n "${Cloud_Num}" ] || Cloud_Num="$(echo "${CLOUD_Version}" | egrep -o "[0-9]{8,}" | tail -n 1)"
[ -n "${Cur_Num}" ] || Cur_Num="$(echo "${CURRENT_Version}" | egrep -o "[0-9]{8,}" | tail -n 1)"
if [[ -z "${Cur_Num}" || -z "${Cloud_Num}" ]]; then
	TIME r "版本号解析失败(本地: ${CURRENT_Version} / 云端: ${CLOUD_Version}),已中止,请手动确认!"
	echo
	exit 1
fi
if [[ ! "${Force_Update}" == 1 ]];then
  	if [[ "${Cur_Num}" -lt "${Cloud_Num}" ]];then
		TIME r "检测到有可更新的固件版本,立即更新固件!"
	fi
  	if [[ "${Cur_Num}" -eq "${Cloud_Num}" ]];then
		[[ "${AutoUpdate_Mode}" == 1 ]] && exit 0
		TIME && read -p "当前版本和云端最新版本一致，是否还要重新安装固件?[Y/n]:" Choose
		[[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]] && {
			TIME z "正在开始重新安装固件..."
		} || {
			TIME r "已取消重新安装固件,即将退出程序..."
			sleep 2
			exit 0
		}
	fi
  	if [[ "${Cur_Num}" -gt "${Cloud_Num}" ]];then
		[[ "${AutoUpdate_Mode}" == 1 ]] && exit 0
		TIME && read -p "云端最高版本,低于您现在的版本,是否强制覆盖现有固件?[Y/n]:" Choose
		[[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]] && {
			TIME z "正在开始使用云端版本覆盖现有固件..."
		} || {
			TIME r "已取消覆盖固件,退出程序..."
			sleep 2
			exit 0
		}
	fi
fi
TIME g "列出详细信息..."
sleep 1
echo -e "\n固件作者：${Author}"
echo "设备名称：${CURRENT_Device}"
echo "固件格式：${Firmware_SFX}"
[[ "${DEFAULT_Device}" == x86-64 ]] && {
	echo "引导模式：${EFI_Mode}"
}
echo "固件名称：${Firmware}"
echo "下载保存：${Download_Path}"
echo "固件体积：${CLOUD_Firmware_Size}M"
cd "${Download_Path}"
# 2026-10-24: 原来整段下载被 `Installed_PKG_List =~ curl` 门控且没有 else ——
# 精简配置里去掉 OpenClash 后 curl 不存在, 就完全不下固件, 随后在 .sha256 那一步报"未取得清单"。
# 改成无条件下载; curl 只用来判断是否处于代理环境, 仅影响提示文案。
export Google_Check="$(command -v curl >/dev/null 2>&1 && curl -I -s --connect-timeout 8 google.com -w %{http_code} | tail -n1)"
if [ "${Google_Check}" = "301" ]; then
	TIME g "检测到代理环境, 正在下载云端固件,请耐心等待..."
else
	TIME g "正在下载云端固件,请耐心等待..."
fi
wget -q --no-check-certificate --timeout=30 --tries=1 "${Github_Release}/${Firmware}" -O "${Firmware}"
if [[ $? -ne 0 ]];then
	wget -q --no-check-certificate --timeout=60 --tries=3 "${Github_Release}/${Firmware}" -O "${Firmware}"
	if [[ $? -ne 0 ]];then
		TIME r "下载云端固件失败,请尝试手动安装!"
		echo
		exit 1
	fi
fi
TIME y "下载云端固件成功!"
# 2026-10-09: 若发布里附带 <固件>.sha256 清单, 先用完整 SHA256 校验固件
# (下面基于"文件名 12 位片段"的校验只能防传输损坏: 文件与文件名一起被换就失效)
SideCar="${Firmware}.sha256"
# 2026-10-24: 与包内 /usr/bin/AutoUpdate 行为对齐, 缺 --no-check-certificate 时设备 CA 旧/时钟不准会直接失败
if ! wget -q --no-check-certificate --timeout=15 --tries=1 "${Github_Release}/${SideCar}" -O "${Download_Path}/${SideCar}" 2>/dev/null || [ ! -s "${Download_Path}/${SideCar}" ]; then
	TIME r "未取得 ${SideCar},无法校验固件完整性,已中止!"
	TIME z "请确认该发布已附带 ${SideCar} 校验清单,不要跳过校验刷机"
	echo
	exit 1
fi
EXPECT_SHA="$(awk '{print $1}' "${Download_Path}/${SideCar}")"
EXPECT_NAME="$(awk '{print $2}' "${Download_Path}/${SideCar}")"
ACTUAL_SHA="$(sha256sum "${Download_Path}/${Firmware}" | awk '{print $1}')"
# 2026-10-28: 签名清单是 `sha256  filename`, 之前只比第一列。若只比哈希,
# 中间人可以把旧固件 + 旧签名清单一起重放; 必须同时校验清单里的文件名,
# 否则"当前 API 名字 + 旧签名固件"也能通过。兼容 ./ 前缀和 sha256sum -b 的 * 前缀。
EXPECT_NAME="${EXPECT_NAME#\*}"
EXPECT_NAME="${EXPECT_NAME##*/}"
if [ -z "${EXPECT_NAME}" ] || [ "${EXPECT_NAME}" != "${Firmware}" ]; then
	TIME r "签名清单文件名与当前固件不一致(清单: ${EXPECT_NAME:-空} / 当前: ${Firmware}),已中止!"
	echo
	exit 1
fi
if ! echo "${EXPECT_SHA}" | grep -qE '^[0-9a-fA-F]{64}$'; then
	TIME r "校验清单格式异常,已中止!"
	echo
	exit 1
fi
if [ "${EXPECT_SHA}" != "${ACTUAL_SHA}" ]; then
	TIME r "完整SHA256校验失败,固件可能被替换或损坏,已中止!"
	echo
	exit 1
fi
TIME g "完整SHA256校验通过"

# 2026-10-21: 校验清单的 Ed25519 签名(公钥随固件分发), 防止"固件 + 校验清单"被同源整体替换
# 只签 .sha256 这个小文件, 固件本身再由上面的 64 位 SHA256 绑定, 免得把几十 MB 全读进内存
SIGN_PUB="/etc/firmware-signing.pub"
SIGN_FILE="${Download_Path}/${SideCar}.sig"
if ! command -v openssl >/dev/null 2>&1; then
	TIME r "系统缺少 openssl, 无法验证固件签名, 已中止!"
	echo
	exit 1
fi
if [ ! -s "${SIGN_PUB}" ]; then
	TIME r "缺少固件签名公钥 ${SIGN_PUB}, 无法验证固件来源, 已中止!"
	TIME z "该公钥由固件自带, 缺失说明本机固件被改动过, 请手动刷机"
	echo
	exit 1
fi
if ! wget -q --no-check-certificate --timeout=15 --tries=1 "${Github_Release}/${SideCar}.sig" -O "${SIGN_FILE}" 2>/dev/null || [ ! -s "${SIGN_FILE}" ]; then
	TIME r "未取得 ${SideCar}.sig, 该发布未签名, 已中止!"
	TIME z "无签名发布无法确认来源(可能是旧版本, 也可能已被替换), 需要升级请手动刷机"
	echo
	exit 1
fi
if ! openssl pkeyutl -verify -pubin -inkey "${SIGN_PUB}" -rawin -in "${Download_Path}/${SideCar}" -sigfile "${SIGN_FILE}" >/dev/null 2>&1; then
	TIME r "固件签名校验失败, 固件来源不可信, 已中止!"
	echo
	exit 1
fi
TIME g "固件签名校验通过"

export CLOUD_MD5=$(md5sum "${Firmware}" | cut -c1-4)
export CLOUD_256=$(sha256sum "${Firmware}" | cut -c4-11)
export MD5_256=$(echo ${Firmware} | egrep -o "[a-zA-Z0-9]+${Firmware_SFX}" | sed -r "s/(.*)${Firmware_SFX}/\1/")
export CURRENT_MD5="$(echo "${MD5_256}" | cut -c1-4)"
export CURRENT_256="$(echo "${MD5_256}" | cut -c5-)"
[[ ${CURRENT_MD5} != ${CLOUD_MD5} ]] && {
	TIME r "MD5对比失败,固件可能在下载时损坏,请检查网络后重试!"
	exit 1
}
[[ ${CURRENT_256} != ${CLOUD_256} ]] && {
	TIME r "SHA256对比失败,固件可能在下载时损坏,请检查网络后重试!"
	exit 1
}
chmod +x "${Firmware}"
TIME g "准备更新固件,更新期间请不要断开电源或重启设备 ..."
[[ "${Input_Other}" == "-t" ]] && {
	TIME z "测试模式运行完毕!"
	rm -rf "${Download_Path}"
	echo
	exit 0
}
sleep 2
TIME g "正在更新固件,请耐心等待 ..."
# 2026-10-22: 原来这里会 `opkg remove gzip` 再升级。但 busybox tar 的 -z 是调用外部 gzip
# 二进制实现的(设备实测 PATH=/nonexistent busybox tar -czf x → "can't execute 'gzip'"),
# 而下一条 sysupgrade -b 内部就是 tar czf → 删掉 gzip 会让备份失败、退化成不保留配置升级。
# 镜像解压走 get_image 的 busybox zcat, 不需要外部 gzip, 所以这一步直接去掉。
# [[ "$(cat ${PKG_List})" =~ gzip ]] && opkg remove gzip > /dev/null 2>&1
if [[ "${AutoUpdate_Mode}" == 1 ]] || [[ "${Update_Mode}" == 1 ]]; then
	# 2026-10-23: /etc/deletefile 由 $DELETE 控制, 只有 Lienol/Mortal 的 diy-part.sh 会写,
	# Lede 分支从来不生成。原来裸 source 一个不存在的文件在 ash 下会直接退出(rc=2),
	# 等于手动升级通道在某些 shell 下静默失败; 加 [ -f ] 守卫, 存在才 source。
	[ -f /etc/deletefile ] && . /etc/deletefile
	# 2026-10-29: 不把 /etc/config/network 复制到 /mnt。
	# sysupgrade -b 的配置备份本身包含 /etc/config/network; /mnt 副本既无用又会暴露 PPPoE 凭据。
	# 2026-10-28: 这里原本先 `mv /etc/config/luci /etc/config/luci-` 再 sysupgrade -b。
	#   打包那一刻 luci 已经被改名, 备份里根本没有 /etc/config/luci, 只多出一个 luci- 野文件;
	#   紧接着 -f 用这份残缺 tar 顶替 sysupgrade 自己生成的完整备份, 于是每升一次级,
	#   主题/语言/会话设置都回到默认值。备份必须原样包含 /etc/config/luci。
	#   备份文件也从 /mnt 挪到 /tmp: /mnt 就在 overlay 上, 和被升级的系统同一块盘, 掉电必一起丢;
	#   sysupgrade 会把这份 tar 复制进新系统, 不依赖重启后它还在。
	#   原来失败兜底写的是 sysupgrade -q, 注释还说是"不保留配置" —— -q 只是静默, -n 才不保留配置。
	#   这里改成裸 sysupgrade: 备份都做不出来时, 让 sysupgrade 用自己的自动备份并如实报错,
	#   而不是假装配置已经被保住了。
	if ( umask 077; sysupgrade -b "${Download_Path}/back.tar.gz" ); then
		chmod 600 "${Download_Path}/back.tar.gz" 2>/dev/null || true
		export Upgrade_Options="sysupgrade -f ${Download_Path}/back.tar.gz"
	else
		export Upgrade_Options="sysupgrade"
	fi
fi

# 2026-10-30: 正常升级先做兼容性检查; 只有显式 -f/-s 的强制路径才跳过。
case "${Upgrade_Options}" in
	*" -F"*) : ;;
	*)
		if ! sysupgrade -T "${Firmware}"; then
			echo "镜像兼容性检查失败(sysupgrade -T), 已中止; 如确认强制刷机请手动执行 sysupgrade -F" >&2
			exit 1
		fi
		;;
esac
# 2026-10-30: 传递 sysupgrade 的真实退出码; 原来无论成功失败都 exit 0,
# 定时任务/上层界面会把失败当成功。
${Upgrade_Options} "${Firmware}"
RC=$?
if [ "${RC}" -ne 0 ]; then
	echo "升级命令失败, rc=${RC}: ${Upgrade_Options} ${Firmware}" >&2
	exit "${RC}"
fi

exit 0

