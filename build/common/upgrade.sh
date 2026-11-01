#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Functions

GET_TARGET_INFO() {
	[[ ${TARGET_PROFILE} == x86-64 ]] && {
		[[ `grep -c "CONFIG_TARGET_IMAGES_GZIP=y" ${Home}/.config` -ge '1' ]] && Firmware_sfxo=img.gz || Firmware_sfxo=img 
	}
	case "${REPO_BRANCH}" in
	"master")
		LUCI_Name="18.06"
		REPO_Name="lede"
		ZUOZHE="coolsnowwolf"
		if [[ "${TARGET_PROFILE}" == "x86-64" ]]; then
			Legacy_Firmware="openwrt-x86-64-generic-squashfs-combined.${Firmware_sfxo}"
			UEFI_Firmware="openwrt-x86-64-generic-squashfs-combined-efi.${Firmware_sfxo}"
			Firmware_sfx="${Firmware_sfxo}"
		elif [[ "${TARGET_PROFILE}" == "phicomm_k3" ]]; then
			Up_Firmware="openwrt-bcm53xx-generic-phicomm_k3-squashfs.trx"
			Firmware_sfx="trx"
		elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3g" ]]; then
			TARGET_PROFILE="xiaomi_mir3g"
			Up_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
			Firmware_sfx="bin"
		elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3g-v2" ]]; then
			TARGET_PROFILE="xiaomi_mir3gv2"
			Up_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
			Firmware_sfx="bin"
		else
			Up_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
			Firmware_sfx="bin"
		fi
	;;
	"19.07") 
		LUCI_Name="19.07"
		REPO_Name="lienol"
		ZUOZHE="Lienol"
		if [[ "${TARGET_PROFILE}" == "x86-64" ]]; then
			Legacy_Firmware="openwrt-x86-64-combined-squashfs.${Firmware_sfxo}"
			UEFI_Firmware="openwrt-x86-64-combined-squashfs-efi.${Firmware_sfxo}"
			Firmware_sfx="${Firmware_sfxo}"
		elif [[ "${TARGET_PROFILE}" == "phicomm-k3" ]]; then
			Up_Firmware="openwrt-bcm53xx-phicomm-k3-squashfs.trx"
			Firmware_sfx="trx"
		else
			Up_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
			Firmware_sfx="bin"
		fi
	;;
	"openwrt-21.02")
		LUCI_Name="21.02"
		REPO_Name="mortal"
		ZUOZHE="immortalwrt"
		if [[ "${TARGET_PROFILE}" == "x86-64" ]]; then
			Legacy_Firmware="immortalwrt-x86-64-generic-squashfs-combined.${Firmware_sfxo}"
			UEFI_Firmware="immortalwrt-x86-64-generic-squashfs-combined-efi.${Firmware_sfxo}"
			Firmware_sfx="${Firmware_sfxo}"
		elif [[ "${TARGET_PROFILE}" == "phicomm_k3" ]]; then
			Up_Firmware="immortalwrt-bcm53xx-generic-phicomm_k3-squashfs.trx"
			Firmware_sfx="trx"
		elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3g" ]]; then
			TARGET_PROFILE="xiaomi_mir3g"
			Up_Firmware="openwrt-ramips-mt7621-xiaomi_mir3g-squashfs-sysupgrade.bin"
			Firmware_sfx="bin"
		elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3g-v2" ]]; then
			TARGET_PROFILE="xiaomi_mir3gv2"
			Up_Firmware="openwrt-ramips-mt7621-xiaomi_mir3gv2-squashfs-sysupgrade.bin"
			Firmware_sfx="bin"
		else
			Up_Firmware="immortalwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
			Firmware_sfx="bin"
		fi
	;;
	esac
	if [ "${REGULAR_UPDATE}" = "true" ]; then
		AutoUpdate_Version=$(egrep -o "V[0-9].+" ${Home}/package/base-files/files/bin/AutoUpdate.sh | awk 'END{print}')
	else
		AutoUpdate_Version=OFF
	fi
	In_Firmware_Info="${Home}/package/base-files/files/bin/openwrt_info"
	Github_Release="${Github}/releases/download/AutoUpdate"
	Github_UP_RELEASE="${Github}/releases/AutoUpdate"
	Openwrt_Version="${REPO_Name}-${TARGET_PROFILE}-${Compile_Date}"
	Egrep_Firmware="${LUCI_Name}-${REPO_Name}-${TARGET_PROFILE}"
}

Diy_Part1() {
# 2026-10-24: 这是 luci-app-autoupdate 进镜像的唯一入口, 原来 sed 静默失效也不会报错 ——
# 上游把 DEFAULT_PACKAGES 改成 := 或换行后, 构建照样绿, 但镜像里没有 LuCI 升级页。
# 2026-11-01: 逐文件处理并回读断言, 不能再用 grep target/linux/*/Makefile 的"任意命中"。
P1_MATCHED=0
for P1_MK in target/linux/*/Makefile; do
	[ -f "$P1_MK" ] || continue
	grep -q 'DEFAULT_PACKAGES' "$P1_MK" || continue
	P1_MATCHED=$((P1_MATCHED + 1))
	# 逐个包名补入, 已有则不重复追加 —— 重复执行 Diy_Part1 也保持幂等。
	for P1_PKG in luci-app-autoupdate luci-app-ttyd; do
		if ! grep -q "$P1_PKG" "$P1_MK"; then
			sed -i "s/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += $P1_PKG/" "$P1_MK" || {
				echo "!! Diy_Part1: 写入 $P1_PKG 失败: $P1_MK"; exit 1
			}
		fi
		grep -q "$P1_PKG" "$P1_MK" || { echo "!! Diy_Part1: $P1_MK 未加入 $P1_PKG"; exit 1; }
	done
done
[ "$P1_MATCHED" -gt 0 ] || { echo "!! Diy_Part1: 没有任何 target/linux/*/Makefile 含 DEFAULT_PACKAGES"; exit 1; }
}

Diy_Part2() {
	GET_TARGET_INFO
	cat >${In_Firmware_Info} <<-EOF
	Github=${Github}
	Luci_Edition=${OpenWrt_name}
	CURRENT_Version=${Openwrt_Version}
	DEFAULT_Device=${TARGET_PROFILE}
	Firmware_Type=${Firmware_sfx}
	LUCI_Name=${LUCI_Name}
	REPO_Name=${REPO_Name}
	Github_Release=${Github_Release}
	Egrep_Firmware=${Egrep_Firmware}
	Download_Path=/tmp/Downloads
	Version=${AutoUpdate_Version}
	Download_Tags=/tmp/Downloads/Github_Tags
	EOF
}

Diy_Part3() {
	GET_TARGET_INFO
	AutoBuild_Firmware="${LUCI_Name}-${Openwrt_Version}"
	Firmware_Path="${Home}/upgrade"
	Mkdir "${Home}/bin/Firmware"
	[ -d "$Firmware_Path" ] || { echo "!! Diy_Part3: 固件目录不存在: $Firmware_Path"; exit 1; }
	if compgen -G "${Firmware_Path}/*sysupgrade.bin" >/dev/null; then
		Up_BinFirmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
		mv "${Firmware_Path}"/*sysupgrade.bin "${Home}/bin/Firmware/${Up_BinFirmware}" || {
			echo "!! Diy_Part3: 无法暂存 sysupgrade.bin"; exit 1
		}
		[ -s "${Home}/bin/Firmware/${Up_BinFirmware}" ] || { echo "!! Diy_Part3: sysupgrade.bin 暂存后为空"; exit 1; }
		mv "${Home}/bin/Firmware/${Up_BinFirmware}" "${Firmware_Path}/${Up_BinFirmware}" || {
			echo "!! Diy_Part3: 无法恢复 sysupgrade.bin"; exit 1
		}
	fi
	cd "${Firmware_Path}" || { echo "!! Diy_Part3: 无法进入 $Firmware_Path"; exit 1; }
	if [[ `ls | grep -c "xiaomi_mi-router-3g"` -ge '1' ]]; then
		rename -v "s/xiaomi_mi-router-3g/xiaomi_mir3g/" * > /dev/null 2>&1 || {
			echo "!! Diy_Part3: xiaomi_mi-router-3g 重命名失败"; exit 1
		}
	fi
	if [[ `ls | grep -c "xiaomi_mi-router-3g-v2"` -ge '1' ]]; then
		rename -v "s/xiaomi_mi-router-3g-v2/xiaomi_mir3gv2/" * > /dev/null 2>&1 || {
			echo "!! Diy_Part3: xiaomi_mi-router-3g-v2 重命名失败"; exit 1
		}
	fi
	case "${TARGET_PROFILE}" in
	x86-64)
		[ -e "${Legacy_Firmware}" ] || { echo "!! Diy_Part3: 缺少 Legacy 镜像 ${Legacy_Firmware}"; exit 1; }
		[ -e "${UEFI_Firmware}" ] || { echo "!! Diy_Part3: 缺少 UEFI 镜像 ${UEFI_Firmware}"; exit 1; }
		MD5=$(md5sum "${Legacy_Firmware}" | cut -c1-4)
		SHA256=$(sha256sum "${Legacy_Firmware}" | cut -c4-11)
		SHA5BIT="${MD5}${SHA256}"
		cp "${Legacy_Firmware}" "${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy-${SHA5BIT}.${Firmware_sfx}" || {
			echo "!! Diy_Part3: 复制 Legacy 镜像失败"; exit 1
		}
		[ -s "${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy-${SHA5BIT}.${Firmware_sfx}" ] || {
			echo "!! Diy_Part3: Legacy 镜像复制后为空"; exit 1
		}
		MD5=$(md5sum "${UEFI_Firmware}" | cut -c1-4)
		SHA256=$(sha256sum "${UEFI_Firmware}" | cut -c4-11)
		SHA5BIT="${MD5}${SHA256}"
		cp "${UEFI_Firmware}" "${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI-${SHA5BIT}.${Firmware_sfx}" || {
			echo "!! Diy_Part3: 复制 UEFI 镜像失败"; exit 1
		}
		[ -s "${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI-${SHA5BIT}.${Firmware_sfx}" ] || {
			echo "!! Diy_Part3: UEFI 镜像复制后为空"; exit 1
		}
	;;
	friendlyarm_nanopi-r2s | friendlyarm_nanopi-r4s | armvirt)
		echo "R2S/R4S/N1/晶晨系列,暂不支持定时更新固件!" > Update_Logs.json
		cp Update_Logs.json "${Home}/bin/Firmware/Update_Logs.json" || { echo "!! Diy_Part3: 写入 Update_Logs.json 失败"; exit 1; }
	;;
	*)
		if [ -e "${Up_Firmware}" ]; then
			MD5=$(md5sum "${Up_Firmware}" | cut -c1-4)
			SHA256=$(sha256sum "${Up_Firmware}" | cut -c4-11)
			SHA5BIT="${MD5}${SHA256}"
			cp "${Up_Firmware}" "${Home}/bin/Firmware/${AutoBuild_Firmware}-Sysupg-${SHA5BIT}.${Firmware_sfx}" || {
				echo "!! Diy_Part3: 复制 Sysupg 镜像失败"; exit 1
			}
		else
			echo "Firmware is not detected !"
		fi
	;;
	esac
	cd "${Home}" || { echo "!! Diy_Part3: 无法返回 $Home"; exit 1; }
}

Mkdir() {
	_DIR=${1}
	if [ ! -d "${_DIR}" ];then
		mkdir -p ${_DIR}
	fi
	unset _DIR
}
