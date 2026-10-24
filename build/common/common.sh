#!/bin/bash
# https://github.com/Lul1a8y/AutoBuild-OpenWrt
# common Module by Lul1a8y
# matrix.target=${Modelfile}

TIME() {
Compte=$(date +%Y年%m月%d号%H时%M分)
[[ -z "$1" ]] && {
	echo -ne " "
} || {
     case $1 in
	r) export Color="\e[31m";;
	g) export Color="\e[32m";;
	b) export Color="\e[34m";;
	y) export Color="\e[33m";;
	z) export Color="\e[35m";;
	l) export Color="\e[36m";;
      esac
	[[ $# -lt 2 ]] && echo -e "\e[36m\e[0m ${1}" || {
		echo -e "\e[36m\e[0m ${Color}${2}\e[0m"
	 }
      }
}

################################################################################################################
# LEDE源码通用diy.sh文件
################################################################################################################
Diy_lede() {
# 【当前不可达】${Modelfile} 恒为矩阵里的 Lede_source, 下面的 openwrt_amlogic 分支永不执行(保留待恢复)

if [[ ! "${Modelfile}" == "openwrt_amlogic" ]]; then
	sed -i '/IMAGES_GZIP/d' "${PATH1}/${CONFIG_FILE}" > /dev/null 2>&1
	echo -e "\nCONFIG_TARGET_IMAGES_GZIP=y" >> "${PATH1}/${CONFIG_FILE}"
fi
if [[ "${Modelfile}" == "openwrt_amlogic" ]]; then

	# luci-app-cpufreq修改一些代码适配amlogic
	sed -i 's/LUCI_DEPENDS.*/LUCI_DEPENDS:=\@\(arm\|\|aarch64\)/g' feeds/luci/applications/luci-app-cpufreq/Makefile
	
fi
}


################################################################################################################
# LIENOL源码通用diy.sh文件
# 【当前不可达】REPO_BRANCH 在 settings.ini 中被锁为 master, 只有 19.07 才会调用 Diy_lienol。
################################################################################################################
Diy_lienol() {

find . -name 'luci-app-netdata' -o -name 'netdata' -o -name 'luci-theme-argon' | xargs -i rm -rf {}
find . -name 'ddns-scripts_aliyun' -o -name 'ddns-scripts_dnspod' -o -name 'luci-app-wol' | xargs -i rm -rf {}
find . -name 'luci-app-wrtbwmon' -o -name 'wrtbwmon' -o -name 'pdnsd-alt' | xargs -i rm -rf {}
rm -rf feeds/packages/libs/libcap
}


################################################################################################################
# 天灵源码18.06 diy.sh文件
# 【当前不可达】同上, 只有 REPO_BRANCH=openwrt-18.06/21.02 才会调用。
################################################################################################################
Diy_mortal() {

find . -name 'luci-app-argon-config' -o -name 'luci-theme-argon' -o -name 'luci-light' | xargs -i rm -rf {}
find . -name 'luci-app-netdata' -o -name 'netdata' -o -name 'luci-theme-openwrt' -o -name 'luci-app-cifs' | xargs -i rm -rf {}
find . -name 'luci-app-wrtbwmon' -o -name 'wrtbwmon' | xargs -i rm -rf {}
}


################################################################################################################
# 全部作者源码公共diy.sh文件
################################################################################################################
Diy_all() {

if [[ ${REGULAR_UPDATE} == "true" ]]; then
	# 2026-10-21: 固定 commit, 不再跟随上游 master(上游改主分支/删库/推坏提交都会直接炸构建)
	# 升级时改下面 checkout 的 SHA 即可: git ls-remote https://github.com/281677160/luci-app-autoupdate HEAD
	APP_DIR="feeds/luci/applications/luci-app-autoupdate"
	git clone https://github.com/281677160/luci-app-autoupdate "${APP_DIR}" || { echo "!! luci-app-autoupdate 拉取失败, 构建中止"; exit 1; }
	git -C "${APP_DIR}" checkout -q 04f2a3708ec0bb216c6dec2e51695f6a7e906a56 || { echo "!! luci-app-autoupdate 固定 commit 校验失败, 构建中止"; exit 1; }
	cp -Rf "${PATH1}"/{AutoUpdate.sh,replace.sh} package/base-files/files/bin
	# 2026-10-24: 发布说明让用户执行 bash /bin/AutoUpdate.sh, 拷贝失败时原来构建照样绿
	[ -x package/base-files/files/bin/AutoUpdate.sh ] || { echo "!! /bin/AutoUpdate.sh 未就位(发布说明里的手动升级命令会失效)"; exit 1; }
	sed -i 's/"定时更新"/"更新固件"/g' feeds/luci/applications/luci-app-autoupdate/po/zh-cn/autoupdate.po
	sed -i 's/定时更新 LUCI/固件更新 LUCI/g' feeds/luci/applications/luci-app-autoupdate/po/zh-cn/autoupdate.po
fi
if [[ "${REPO_BRANCH}" == "master" ]]; then
	cp -Rf "${Home}"/build/common/LEDE/files "${Home}"
	cp -Rf "${Home}"/build/common/LEDE/diy/* "${Home}"
	cp -Rf "${Home}"/build/common/LEDE/patches/* "${PATH1}/patches"
elif [[ "${REPO_BRANCH}" == "19.07" ]]; then
	cp -Rf "${Home}"/build/common/LIENOL/files "${Home}"
	cp -Rf "${Home}"/build/common/LIENOL/diy/* "${Home}"
	cp -Rf "${Home}"/build/common/LIENOL/patches/* "${PATH1}/patches"
elif [[ "${REPO_BRANCH}" == "openwrt-18.06" ]]; then
	cp -Rf "${Home}"/build/common/MORTAL/files "${Home}"
	cp -Rf "${Home}"/build/common/MORTAL/diy/* "${Home}"
	cp -Rf "${Home}"/build/common/MORTAL/patches/* "${PATH1}/patches"

fi
if [ -n "$(ls -A "${PATH1}/diy" 2>/dev/null)" ]; then
	cp -Rf "${PATH1}"/diy/* "${Home}"
fi
if [ -n "$(ls -A "${PATH1}/files" 2>/dev/null)" ]; then
	cp -Rf "${PATH1}/files" "${Home}" && chmod -R +x ${Home}/files
fi
if [ -n "$(ls -A "${PATH1}/patches" 2>/dev/null)" ]; then
	find "${PATH1}/patches" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d './' -p1 --forward --no-backup-if-mismatch"
fi
}

################################################################################################################
# s905x3_s905x2_s905x_s905d_s922x_s912 一键打包脚本
# 【当前不可达】matrix 只有 Lede_source, 且 AUTOMATIC_AMLOGIC 不在 settings.ini 中设置;
# workflow 的 if 判断永远不会成立。保留是为了以后恢复 amlogic 打包时不用重写(上游 281677160 模板)。
################################################################################################################
Diy_amlogic() {
if [[ -n "$(ls -A "$GITHUB_WORKSPACE/amlogic_openwrt" 2>/dev/null)" ]]; then
        git clone https://github.com/mdtycl/amlogic-s905d
#	git clone https://github.com/ophub/amlogic-s9xxx-openwrt
	mv amlogic-s905d/{amlogic-s9xxx,make} $GITHUB_WORKSPACE
	rm -rf amlogic-s905d
	source $GITHUB_WORKSPACE/amlogic_openwrt
	if [[ ${amlogic_kernel} == "5.4.155" ]]; then
		curl -fsSL https://raw.githubusercontent.com/ophub/amlogic-s9xxx-openwrt/main/.github/workflows/build-openwrt-lede.yml > open.yml
		Make_kernel="$(cat open.yml | grep ./make | cut -d "k" -f3 | sed s/[[:space:]]//g)"
		amlogic_kernel="${Make_kernel}"
	else
		amlogic_kernel="${amlogic_kernel}"
	fi
	if [[ -z "${Make_kernel}" ]];then
		amlogic_kernel="5.4.155"
	fi
	mkdir -p $GITHUB_WORKSPACE/openwrt-armvirt
	cp -Rf ${Home}/bin/targets/*/*/*.tar.gz $GITHUB_WORKSPACE/openwrt-armvirt/ && sync
	sudo chmod +x make
	sudo ./make -d -b "${amlogic_model}" -k "${amlogic_kernel}"
	cp -Rf $GITHUB_WORKSPACE/out/* ${Home}/bin/targets/*/*
else
	TIME r "缺少打包所需的组合文件，您或者把diy-part.sh组合代码删除了"
fi
}

################################################################################################################
# 判断脚本是否缺少主要文件（如果缺少settings.ini设置文件在检测脚本设置就运行错误了）
################################################################################################################
Diy_settings() {
rm -rf ${Home}/build/QUEWENJIANerros
if [ -z "$(ls -A "$PATH1/${CONFIG_FILE}" 2>/dev/null)" ]; then
	echo
	TIME r "错误提示：编译脚本缺少[${CONFIG_FILE}]名称的配置文件,请在[build/${Modelfile}]文件夹内补齐"
	echo "errors" > ${Home}/build/QUEWENJIANerros
	echo
fi
if [ -z "$(ls -A "$PATH1/${DIY_PART_SH}" 2>/dev/null)" ]; then
	echo
	TIME r "错误提示：编译脚本缺少[${DIY_PART_SH}]名称的自定义设置文件,请在[build/${Modelfile}]文件夹内补齐"
	echo "errors" > ${Home}/build/QUEWENJIANerros
	echo
fi
if [ -n "$(ls -A "${Home}/build/QUEWENJIANerros" 2>/dev/null)" ]; then
rm -rf ${Home}/build/QUEWENJIANerros
exit 1
fi
# 2026-10-20: 这里是 `rm -rf {build,README.md}`(相对当前目录)。Diy_settings 是在「加载设置」
# 步骤开头、`cd openwrt` 之前调用的, 当时 cwd 还是 $GITHUB_WORKSPACE —— 所以被删掉的是
# 仓库里那份**原始** build/, 不是拷进 openwrt 的那份。而原始 build/<target>/.config 和
# settings.ini 正是工作流缓存 key 的 hashFiles 输入: 删掉之后 hashFiles 恒为空,
# 缓存 key 永远是 "Linux-Lede_source-openwrt-"(结尾空哈希), 配置文件怎么改都不会失效,
# 于是 10-09 那份旧 staging_dir 被无限复用 —— 这是 geoview 编译失败与构建缓慢的总根源。
# 原始 build/ 后续没有任何步骤依赖"它不存在", 保留它反而让 key/指纹恢复有效, 故不再删除。
# (原来顺手删的根目录 README.md 同样没有下游依赖, 一并保留。)
}


################################################################################################################
# 判断插件冲突
################################################################################################################
Diy_chajian() {
echo
# 2026-10-21: 删掉这里的 make defconfig —— 工作流「生成配置」步骤在调用本函数后
# **紧接着**又跑了一次, 且那次是 `make defconfig || { 报错; exit 1; }`。原来这里那次
# 输出被 /dev/null 吞掉, 失败也看不见, 等于让 -e 静默中止; 保留带错误检查的那次即可。
# 本函数只用 Chajianlibiao 目录内容生成 CHONGTU, 不读 .config, 去掉无副作用。
echo "TIME b \"					插件冲突信息\"" > ${Home}/CHONGTU

if [ -n "$(ls -A "${Home}/Chajianlibiao" 2>/dev/null)" ]; then
	echo "TIME y \"  插件冲突会导致编译失败，以上操作如非您所需，请关闭此次编译，重新开始编译，避开冲突重新选择插件\"" >>CHONGTU
	echo "TIME z \"\"" >>CHONGTU
else
	rm -rf CHONGTU
fi
}


################################################################################################################
# 为编译做最后处理
################################################################################################################
Diy_chuli() {

# ===== 2026-10-17: rc.local 注入改为「标记块 + 幂等」=====
# 旧实现: sed -i '$ s/exit 0$//' 后无条件 echo >> —— 没有标记, 重复执行就重复注入;
# 注入块里还带 /etc/init.d/network restart + uhttpd restart(每次开机重启网络, 会让 eth0
# 在 100M→2.5G 重协商期间再抖一次; 网络本身由 procd 正常拉起, 不需要这两行)。
RC="${Home}/package/base-files/files/etc/rc.local"
[ -f "$RC" ] || { echo "!! rc.local 不存在: $RC"; exit 1; }
RC_BEGIN='# >>> hermes-managed (i225 EEE) >>>'
RC_END='# <<< hermes-managed (i225 EEE) <<<'
# 1) 删旧标记块(若有) 2) 删 2026-08 无标记旧版块(头行到其后的 exit 0) 3) 去尾部空行与结尾 exit 0
awk -v b="$RC_BEGIN" -v e="$RC_END" -v legacy='# 关闭 Intel i225-V EEE' '
  $0==b {inblk=1; next}
  $0==e {inblk=0; next}
  inblk {next}
  index($0, legacy) > 0 {inleg=1; next}
  inleg { if ($0 ~ /^[[:space:]]*exit 0[[:space:]]*$/) inleg=0; next }
  {buf[++n]=$0}
  END {
    # 顺序要紧: 先摘掉结尾 exit 0, 再清尾部空行 —— 反过来的话, exit 0 被摘掉后
    # 它前面那行空行会留下来, 每次重复执行都 +1 行(首版就这么踩的, 本地用例抓到)。
    if (n>0 && buf[n] ~ /^[[:space:]]*exit 0[[:space:]]*$/) n--
    while (n>0 && buf[n] ~ /^[[:space:]]*$/) n--
    for (i=1;i<=n;i++) print buf[i]
  }' "$RC" > "$RC.new" && mv "$RC.new" "$RC"
# 4) 只追加一次
{
  echo ""
  echo "$RC_BEGIN"
  echo "# 关闭 Intel i225-V EEE，防止 LAN 口链路抖动和 TX 队列超时 (2026-08-06)"
  echo "# 2026-10-17: 不在此处 restart network/uhttpd —— 网络由 procd 负责, 开机重启会让网口再抖一次"
  echo "for iface in eth0 eth1 eth2 eth3; do"
  echo "	[ -x /usr/sbin/ethtool ] && ethtool --set-eee \$iface eee off 2>/dev/null"
  echo "done"
  echo "$RC_END"
  echo "exit 0"
} >> "$RC"
# 5) 自检: 恰好一段标记 / 恰好一个 exit 0 / 不得残留 restart
[ "$(grep -cF "$RC_BEGIN" "$RC")" = "1" ] || { echo "!! rc.local: 起始标记数量异常"; exit 1; }
[ "$(grep -cF "$RC_END" "$RC")" = "1" ] || { echo "!! rc.local: 结束标记数量异常"; exit 1; }
[ "$(grep -cE '^[[:space:]]*exit 0[[:space:]]*$' "$RC")" = "1" ] || { echo "!! rc.local: exit 0 不是恰好 1 个"; exit 1; }
if grep -qE '/etc/init\.d/(network|uhttpd)[[:space:]]+restart' "$RC"; then
  echo "!! rc.local 仍含 network/uhttpd restart"; exit 1
fi
echo "== rc.local 注入完成(单块, 无网络重启) =="

if [[ "${REPO_BRANCH}" == "19.07" ]]; then
	sed -i 's/PATCHVER:=4.9/PATCHVER:=4.14/g' target/linux/*/Makefile
	sed -i 's/PATCHVER:=4.19/PATCHVER:=4.14/g' target/linux/*/Makefile
fi

if [[ "${TARGET_BOARD}" == "x86" ]]; then
	cp -Rf "${Home}"/build/common/Custom/DRM-I915 target/linux/x86/DRM-I915
	for X in $(ls -1 target/linux/x86 | grep "config-"); do echo -e "\n$(cat target/linux/x86/DRM-I915)" >> target/linux/x86/${X}; done
fi

if [[ "${BY_INFORMATION}" == "true" ]]; then
	grep -i CONFIG_PACKAGE_luci-app .config | grep  -v \# > Plug-in
	grep -i CONFIG_PACKAGE_luci-theme .config | grep  -v \# >> Plug-in
	if [[ `grep -c "CONFIG_PACKAGE_luci-i18n-qbittorrent-zh-cn=y" ${Home}/.config` -eq '0' ]]; then
		if [[ `grep -c "luci-app-qbittorrent_static" ${Home}/Plug-in` -eq '1' ]]; then
			sed -i '/qbittorrent/d' Plug-in
		fi
	fi
	sed -i '/INCLUDE/d' Plug-in > /dev/null 2>&1
	sed -i '/=m/d' Plug-in > /dev/null 2>&1
	sed -i 's/CONFIG_PACKAGE_/、/g' Plug-in
	sed -i 's/=y/\"/g' Plug-in
	awk '$0=NR$0' Plug-in > Plug-2
	awk '{print "	" $0}' Plug-2 > Plug-in
	sed -i "s/^/TIME g \"/g" Plug-in
	cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c > CPU
        cat /proc/cpuinfo | grep "cpu cores" | uniq >> CPU
        sed -i 's|[[:space:]]||g; s|^.||' CPU && sed -i 's|CPU||g; s|pucores:||' CPU
        CPUNAME="$(awk 'NR==1' CPU)" && CPUCORES="$(awk 'NR==2' CPU)"
        rm -rf CPU

        if [[ "${REPO_BRANCH}" == "openwrt-18.06" ]] || [[ "${REPO_BRANCH}" == "openwrt-21.02" ]]; then
        export KERNEL_PATC=""
        export KERNEL_PATC="$(egrep KERNEL_PATCHVER:=[0-9]+\.[0-9]+ ${Home}/target/linux/${TARGET_BOARD}/Makefile |cut -d "=" -f2)"
        [[ -z ${KERNEL_PATC} ]] && export KERNEL_PATC="$(egrep KERNEL_PATCHVER=[0-9]+\.[0-9]+ ${Home}/target/linux/${TARGET_BOARD}/Makefile |cut -d "=" -f2)"
        [[ -n ${KERNEL_PATC} ]] && export LINUX_KERNEL="$(egrep -o LINUX_KERNEL_HASH-${KERNEL_PATC}\.[0-9]+ ${Home}/include/kernel-version.mk |cut -d "-" -f2)"
        [[ -z ${LINUX_KERNEL} ]] && export LINUX_KERNEL="nono"
        else
        export KERNEL_PATC=""
        export KERNEL_PATC="$(egrep KERNEL_PATCHVER:=[0-9]+\.[0-9]+ ${Home}/target/linux/${TARGET_BOARD}/Makefile |cut -d "=" -f2)"
        [[ -z ${KERNEL_PATC} ]] && export KERNEL_PATC="$(egrep KERNEL_PATCHVER=[0-9]+\.[0-9]+ ${Home}/target/linux/${TARGET_BOARD}/Makefile |cut -d "=" -f2)"
        [[ -n ${KERNEL_PATC} ]] && export LINUX_KERNEL="$(egrep -o LINUX_KERNEL_HASH-${KERNEL_PATC}\.[0-9]+ ${Home}/include/kernel-${KERNEL_PATC} |cut -d "-" -f2)"
        [[ -z ${LINUX_KERNEL} ]] && export LINUX_KERNEL="nono"
	
	      PATCHVER="unknown"
        fi
	if [[ ! "${PATCHVER}" == "unknown" ]]; then
		PATCHVER=$(egrep -o "${PATCHVER}.[0-9]+" ${Home}/include/kernel-version.mk)
	fi
	
	if [[ "${Modelfile}" == "openwrt_amlogic" ]]; then
		[[ -e $GITHUB_WORKSPACE/amlogic_openwrt ]] && source $GITHUB_WORKSPACE/amlogic_openwrt
		[[ "${amlogic_kernel}" == "5.4.155" ]] && {
			curl -fsSL https://raw.githubusercontent.com/mdtycl/amlogic-s905d/master/.github/workflows/build-openwrt-lede.yml > open.yml
			Make_ker="$(cat open.yml | grep ./make | cut -d "k" -f3 | sed s/[[:space:]]//g)"
			TARGET_kernel="${Make_ker}"
			TARGET_model="${amlogic_model}"
		} || {
			TARGET_kernel="${amlogic_kernel}"
			TARGET_model="${amlogic_model}"
		}
	fi
fi
rm -rf ${Home}/files/{README,README.md}
}


################################################################################################################
# 编译信息
################################################################################################################
Diy_xinxi() {
if [[ "${TARGET_PROFILE}" =~ (friendlyarm_nanopi-r2s|friendlyarm_nanopi-r4s|armvirt) ]]; then
	REGULAR_UPDATE="false"
fi
echo
TIME b "编译源码: ${CODE}"
TIME b "源码链接: ${REPO_URL}"
TIME b "源码分支: ${REPO_BRANCH}"
TIME b "源码作者: ${ZUOZHE}"
TIME b "固件内核: ${LINUX_KERNEL}"
TIME b "Luci版本: ${OpenWrt_name}"
[[ "${Modelfile}" == "openwrt_amlogic" ]] && {
	TIME b "编译机型: ${TARGET_model}"
	TIME b "打包内核: ${TARGET_kernel}"
} || {
	TIME b "编译机型: ${TARGET_PROFILE}"
}
TIME b "固件作者: ${Author}"
TIME b "仓库地址: ${Github}"
TIME b "启动编号: #${Run_number}（${CangKu}仓库第${Run_number}次启动[${Run_workflow}]工作流程）"
TIME b "编译时间: ${Compte}"
[[ "${Modelfile}" == "openwrt_amlogic" ]] && {
	TIME g "您当前使用【${Modelfile}】文件夹编译【${TARGET_model}】固件"
} || {
	TIME g "您当前使用【${Modelfile}】文件夹编译【${TARGET_PROFILE}】固件"
}
echo

if [[ ${UPLOAD_FIRMWARE} == "true" ]]; then
	TIME y "上传固件到github actions: 开启"
else
	TIME r "上传固件到github actions: 关闭"
fi
if [[ ${UPLOAD_CONFIG} == "true" ]]; then
	TIME y "上传[.config]配置文件: 开启"
else
	TIME r "上传[.config]配置文件: 关闭"
fi
if [[ ${UPLOAD_BIN_DIR} == "true" ]]; then
	TIME y "上传BIN文件夹: 开启"
else
	TIME r "上传BIN文件夹: 关闭"
fi
if [[ ${UPLOAD_RELEASE} == "true" ]]; then
	TIME y "发布固件: 开启"
else
	TIME r "发布固件: 关闭"
fi
if [[ ${SERVERCHAN_SCKEY} == "true" ]]; then
	TIME y "电报通知: 开启"
else
	TIME r "电报通知: 关闭"
fi
if [[ ${SSH_ACTIONS} == "true" ]]; then
	TIME y "SSH远程连接: 开启"
else
	TIME r "SSH远程连接: 关闭"
fi
if [[ ${BY_INFORMATION} == "true" ]]; then
	TIME y "编译信息显示: 开启"
fi
if [[ ${SSHYC} == "true" ]]; then
	TIME y "SSH远程连接临时开关: 开启"
fi
if [[ ${REGULAR_UPDATE} == "true" ]]; then
	TIME y "固件在线更新: 开启"
else
	TIME r "固件在线更新: 关闭"
fi
if [[ ${REGULAR_UPDATE} == "true" ]]; then
	echo
	TIME l "固件在线更新信息"
	TIME z "插件版本: ${AutoUpdate_Version}"
	if [[ ${TARGET_PROFILE} == "x86-64" ]]; then
		TIME b "传统固件: ${Legacy_Firmware}"
		TIME b "UEFI固件: ${UEFI_Firmware}"
		TIME b "固件后缀: ${Firmware_sfx}"
	else
		TIME b "固件名称: ${Up_Firmware}"
		TIME b "固件后缀: ${Firmware_sfx}"
	fi
	TIME b "固件版本: ${Openwrt_Version}"
	TIME b "云端路径: ${Github_UP_RELEASE}"
	
else
	echo
fi
echo
TIME z " 文件系统      类型   容量  已用  可用 使用%  挂载点"
cd ../ && df -hT $PWD && cd openwrt
echo
TIME z "  本编译 服务器的 CPU型号为 [ ${CPUNAME} ]"
echo
TIME z "  使用 核心数 为 [ ${CPUCORES} ], 线程数为 [ $(nproc) ]"
echo
TIME z "  随机分配到的 CPU性能, AMDEPYC776364(最快) > 8370C(快) > 8272CL(超时边缘) > 8171M(超时) > E5系列(建议放弃)"
echo
TIME z "  下面将使用 [ $(nproc) 线程 ] 编译固件"
echo

if [ -n "$(ls -A "${Home}/Chajianlibiao" 2>/dev/null)" ]; then
	echo
	echo
	chmod -R +x ${Home}/CHONGTU
	source ${Home}/CHONGTU
	rm -rf {CHONGTU,Chajianlibiao}
	echo
	echo
fi
if [ -n "$(ls -A "${Home}/Plug-in" 2>/dev/null)" ]; then
	TIME r "	      已选插件列表"
	chmod -R +x ${Home}/Plug-in
	source ${Home}/Plug-in
	rm -rf {Plug-in,Plug-2}
	echo
fi
}
