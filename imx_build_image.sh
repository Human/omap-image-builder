#!/bin/bash -e
#
# Copyright (c) 2009-2013 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

SYST=$(uname -n)
HOST_ARCH=$(uname -m)
time=$(date +%Y-%m-%d)

unset USE_OEM

DIR=$PWD
tempdir=$(mktemp -d)

function reset_vars {
	unset EXTRA
	unset USER_PASS

	source ${DIR}/var/pkg_list.sh

	#Hostname:
	FQDN="arm"

	SERIAL="ttyO2"

	IMAGESIZE="2G"
}

function minimal_armel {
	rm -f "${DIR}/.project" || true

	pkgs="${MINIMAL_APT}${EXTRA}"

	base_pkg_list=$(echo ${pkgs} | sed -e 's/,/ /g')

	#Actual Releases will use version numbers..
	case "${DIST}" in
	squeeze)
		#http://www.debian.org/releases/squeeze/
		export_filename="${distro}-6.0.6-console-${dpkg_arch}-${time}"
		;;
	quantal)
		export_filename="${distro}-12.10-console-${dpkg_arch}-${time}"
		;;
	*)
		export_filename="${distro}-${release}-console-${dpkg_arch}-${time}"
		;;
	esac

	tempdir=$(mktemp -d)

	cat > ${DIR}/.project <<-__EOF__
		tempdir="${tempdir}"
		export_filename="${export_filename}"

		distro="${distro}"
		release="${release}"
		dpkg_arch="${dpkg_arch}"

		apt_proxy="${apt_proxy}"
		base_pkg_list="${base_pkg_list}"

		image_hostname="${FQDN}"

		user_name="${user_name}"
		full_name="${full_name}"
		password="${password}"

		chroot_ENABLE_DEB_SRC="${chroot_ENABLE_DEB_SRC}"

		chroot_KERNEL_HTTP_DIR="${chroot_KERNEL_HTTP_DIR}"

	__EOF__

	cat ${DIR}/.project

	/bin/bash -e "${DIR}/RootStock-NG.sh" || { exit 1 ; }
}

function compression {
	echo "Starting Compression"
	cd ${DIR}/deploy/

	tar cvf ${export_filename}.tar ./${export_filename}

	if [ -f ${DIR}/release ] ; then
		echo "xz -z -7 -v ${export_filename}.tar" >> /mnt/farm/testing/pending/compress.txt

		if [ "x${SYST}" == "x${RELEASE_HOST}" ] ; then
			if [ -d /mnt/farm/testing/pending/ ] ; then
				cp -v ${export_filename}.tar /mnt/farm/testing/pending/${export_filename}.tar
			fi
		fi
	fi
	cd ${DIR}/
}

function kernel_chooser {
	wget --no-verbose --directory-prefix=${tempdir}/ http://rcn-ee.net/deb/${release}-${dpkg_arch}/LATEST-${SUBARCH}
	FTP_DIR=$(cat ${tempdir}/LATEST-${SUBARCH} | grep "ABI:1 ${KERNEL_ABI}" | awk '{print $3}')
	FTP_DIR=$(echo ${FTP_DIR} | awk -F'/' '{print $6}')
}

function select_rcn-ee-net_kernel {
	SUBARCH="imx"
	KERNEL_ABI="STABLE"
	kernel_chooser
	chroot_KERNEL_HTTP_DIR="${mirror}/${release}-${dpkg_arch}/${FTP_DIR}/"
}

is_ubuntu () {
	distro="ubuntu"
	user_name="ubuntu"
	password="temppwd"
	full_name="Demo User"
}

is_debian () {
	distro="debian"
	user_name="debian"
	password="temppwd"
	full_name="Demo User"
}

function wheezy_release {
	reset_vars
	is_debian
	release="wheezy"
	select_rcn-ee-net_kernel
	EXTRA=",${DEBIAN_ONLY},lowpan-tools"
	USER_LOGIN="debian"

	COMPONENTS="${DEB_COMPONENTS}"

	minimal_armel
	compression
}

source ${DIR}/var/defaults.sh
source ${DIR}/var/check_host.sh

apt_proxy=""
mirror="http://rcn-ee.net/deb"
if [ -f ${DIR}/rcn-ee.host ] ; then
	source ${DIR}/host/rcn-ee-host.sh
fi

mkdir -p ${DIR}/deploy/

if [ -f ${DIR}/release ] ; then
	chroot_ENABLE_DEB_SRC="enable"
fi

dpkg_arch="armhf"
wheezy_release

echo "done"
