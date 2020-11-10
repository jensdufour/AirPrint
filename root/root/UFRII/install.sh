#!/bin/bash

##############################################################################
##
##  Canon Laser Printer Driver for Linux
##  Copyright CANON INC. 2015
##
##  This program is free software; you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with this program; if not, write to the Free Software
##  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
##############################################################################


#-------------------------------------------------#
# install package list define
#  0x01:CARPS2/UFR2LT Driver
#  0x02:LIPSLX/UFR2 Driver
#  0x04:LIPS4 Driver
#  0x08:PDD Driver
#-------------------------------------------------#
INSTALL_PACKAGE_RPM_32="
0x0E:beecrypt
0x0E:beecrypt-devel
0x0F:libglade2
0x02:zlib"

REPLACE_PACKAGE_RPM_32="
beecrypt,libgcrypt
beecrypt-devel,libgcrypt-devel"

INSTALL_PACKAGE_RPM_64="
0x07:libxml2
0x07:libxml2.i686
0x07:glibc
0x07:glibc.i686
0x07:libstdc++
0x07:libstdc++.i686
0x02:libjpeg-turbo
0x02:libjpeg-turbo.i686
0x0E:beecrypt
0x06:beecrypt.i686
0x08:beecrypt-devel
0x06:beecrypt-devel.i686
0x0F:libglade2
0x02:zlib"

REPLACE_PACKAGE_RPM_64="
beecrypt,libgcrypt
beecrypt.i686,libgcrypt.i686
beecrypt-devel,libgcrypt-devel
beecrypt-devel.i686,libgcrypt-devel.i686"

INSTALL_PACKAGE_DEB_32="
0x0F:libglade2-0
0x02:libjpeg62
0x0E:libbeecrypt7
0x0E:libbeecrypt-dev
0x02:zlib1g"

REPLACE_PACKAGE_DEB_32="
libbeecrypt7,libgcrypt20
libbeecrypt-dev,libgcrypt20-dev"

INSTALL_PACKAGE_DEB_64="
0x0F:libglade2-0
0x07:libstdc++6:i386
0x07:libxml2:i386
0x02:libjpeg62:i386
0x06:libbeecrypt7:i386
0x06:libbeecrypt-dev:i386
0x08:libbeecrypt7
0x08:libbeecrypt-dev
0x02:zlib1g"

REPLACE_PACKAGE_DEB_64="
libbeecrypt7:i386,libgcrypt20:i386
libbeecrypt-dev:i386,libgcrypt20-dev:i386
libbeecrypt7,libgcrypt20
libbeecrypt-dev,libgcrypt20-dev"

INSTALL_PACKAGE_DEB_64_IA32="
0x07:ia32-libs
0x07:libglade2-0
0x02:libjpeg62:i386
0x06:libbeecrypt7:i386
0x06:libbeecrypt-dev:i386
0x02:zlib1g"


#-------------------------------------------------#
# install message
#-------------------------------------------------#
INST_COM_01_01="#----------------------------------------------------#"

INST_ERR_01_01="The current user is %s.
Change user to root, and then perform installation again."
INST_ERR_02_01="Could not install."
INST_MSG_01_01="This installer is recommended for the following distributions that are currently supported as of the release of this installer:
- Fedora/Ubuntu/CentOS 7.3 or later/Debian 8.6 or later

If this installer is run under distributions for which the support period has ended, the installation of additional system libraries may be necessary after driver installation is complete.

Note that an internet connection is required for installation.

Do you want to continue with installation? (y/n)"
INST_MSG_02_01="Some system libraries could not be installed.
Refer to the Readme file for more information.
Do you want to continue with installation? (y/n)"
INST_MSG_03_01="Installation is complete.
Do you want to register the printer now? (y/n)"

LC_FILE_DIR="resources"
LC_FILE="no_localize"    
LANG_INFO=`echo $LANG | tr '[:upper:]' '[:lower:]'`
case "${LANG_INFO##*.}" in
	utf8 | utf-8)
		case "${LANG_INFO%%.*}" in
			ja_jp)
				LC_FILE="installer_ja_utf8.lc"
			;;
			fr_fr)
				LC_FILE="installer_fr_utf8.lc"
			;;
			it_it)
				LC_FILE="installer_it_utf8.lc"
			;;
			de_de)
				LC_FILE="installer_de_utf8.lc"
			;;
			es_es)
				LC_FILE="installer_es_utf8.lc"
			;;
			zh_cn)
				LC_FILE="installer_zh_CN_utf8.lc"
			;;
			ko_kr)
				LC_FILE="installer_ko_utf8.lc"
			;;
			zh_tw)
				LC_FILE="installer_zh_TW_utf8.lc"
			;;
			*)
				LC_FILE="installer_en_utf8.lc"
			;;
		esac
	;;
esac

#-------------------------------------------------#
# etc. define
#-------------------------------------------------#
DRIVER_FLAG=0
ERROR_CHECK=0
DRIVER_ERROR_CHECK=0
MACHINE_TYPE=""
PACKAGE_TYPE=""
RELEASE_DIR=""
DRIVER_PACKAGE=""
INSTALL_PACKAGE=""
INSTALL_CMD=""
INSTALL_OPT=""
INSTALL_PACKAGE_CMD=""

LIST_SPACE=" "

COLOR_K='\033[1;30m'
COLOR_R='\033[1;31m'
COLOR_G='\033[1;32m'
COLOR_Y='\033[1;33m'
COLOR_B=''
COLOR_M='\033[1;35m'
COLOR_C='\033[1;36m'
COLOR_OFF='\033[m'


#-------------------------------------------------#
# common function
#-------------------------------------------------#
C_output_log()
{
	echo -e -n $COLOR_B
	echo -e $INST_COM_01_01
	echo -e "# $1"
	echo -e $INST_COM_01_01
	echo -e -n $COLOR_OFF
}


C_output_message()
{
	echo -e -n $COLOR_B
	echo -e "$1"
	echo -e -n $COLOR_OFF
}


C_output_error_message()
{
	echo -e -n $COLOR_R
	echo -e "$1"
	echo -e -n $COLOR_OFF
}


C_check_distribution()
{	
	read -p "$INST_MSG_01_01" ans
	if [ "$ans" != "y" -a "$ans" != "Y" ]; then
		exit 1
	fi
	echo
}


C_set_driver_flag()
{
	find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE" | grep -i -e carps2 -e ufr2lt > /dev/null 2>&1
	if [ "${?}" -eq 0 ]; then
		DRIVER_FLAG=$(($DRIVER_FLAG | 0x01))
	fi

	find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE" | grep -i -e lipslx  -e ufr2- > /dev/null 2>&1
	if [ "${?}" -eq 0 ]; then
		DRIVER_FLAG=$(($DRIVER_FLAG | 0x02))
	fi

	find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE" | grep -i -e lips4 > /dev/null 2>&1
	if [ "${?}" -eq 0 ]; then
		DRIVER_FLAG=$(($DRIVER_FLAG | 0x04))
	fi
	
	find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE" | grep -i -e pdd  -e settings > /dev/null 2>&1
	if [ "${?}" -eq 0 ]; then
		DRIVER_FLAG=$(($DRIVER_FLAG | 0x08))
	fi
}


C_check_driver_and_install_package()
{
	local lc_package_flag=`echo $INSTALL_PACKAGE | cut -d ':' -f1`

	if [ $(($lc_package_flag & $DRIVER_FLAG)) = $DRIVER_FLAG ]; then
		INSTALL_PACKAGE=`echo $INSTALL_PACKAGE | cut -d ':' -f2-`
	else
		INSTALL_PACKAGE=""	
	fi
}
	

C_check_directory()
{
	echo "${0}" | grep '/' >/dev/null  2>&1
	if [ "${?}" -eq 0 ]; then
		shell_dir="${0%/*}"
		cd "${shell_dir}"
	fi
}


C_init_cups()
{
	C_output_log "cups $1"

	if [ -f /etc/init.d/cups ]
	then
		CMD="/etc/init.d/cups $1"
		echo $CMD
		$CMD
	elif [ -f /etc/init.d/cupsys ]
	then
		CMD="/etc/init.d/cupsys $1"
		echo $CMD
		$CMD
	else
		CMD="service cups $1"
		echo $CMD
		$CMD
	fi
	echo
}


C_update()
{
	case $PACKAGE_TYPE in
	'deb')
		C_output_log "apt-get update"
		apt-get update
		echo
		;;
	'rpm')
		C_output_log "$INSTALL_PACKAGE_CMD upgrade"
		for upgrade_pkg in ${1}
		do
			INSTALL_PACKAGE=$upgrade_pkg

			if [ "$2" != "REPLACE" ]; then
				C_check_driver_and_install_package
				if [ "$INSTALL_PACKAGE" = "" ]; then
					continue;
				fi
			fi
			echo "$INSTALL_PACKAGE"
			$INSTALL_PACKAGE_CMD -y upgrade $INSTALL_PACKAGE
			echo
		done
		;;
	esac
	echo
}


C_install_package()
{
	C_output_log "$INSTALL_PACKAGE_CMD install"

	$INSTALL_PACKAGE_CMD -y install $INSTALL_PACKAGE

	echo
}


C_install_package_check()
{
	C_output_log "Install Package Check"

	replace_list=""
	err_check=0
	for inst_pkg in $INSTALL_PACKAGE
	do
		if which rpm > /dev/null 2>&1;
		then
			echo $inst_pkg | grep '\.'  > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				LIB_NAME=`echo $inst_pkg | cut -d '.' -f1`
				ARCH=`echo $inst_pkg | cut -d '.' -f2`
				rpm -qa | grep -i $LIB_NAME | grep -i $ARCH > /dev/null 2>&1
			else
				rpm -qa | grep -i $inst_pkg > /dev/null 2>&1
			fi
		else
			echo $inst_pkg | grep ":" > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				LIB_NAME=`echo $inst_pkg | cut -d ':' -f1`
				ARCH=`echo $inst_pkg | cut -d ':' -f2`
				dpkg -l | grep -i $LIB_NAME | grep -i $ARCH > /dev/null 2>&1
			else
				dpkg -l | grep -i $inst_pkg > /dev/null 2>&1
			fi
		fi

		if [ $? -eq 0 ]; then
			C_output_message " OK: $inst_pkg"
		else
			#C_output_error_message   " NG: $inst_pkg"
			replace_pkg=""
			for check_pkg in $REPLACE_PACKAGE
			do
				IFS_BACK=$IFS
				IFS=','
				array=($check_pkg)
				IFS=$IFS_BACK
				if [ ${array[0]} = $inst_pkg ]; then
					replace_pkg=${array[1]}
				fi
			done
			if [ "$replace_pkg" != "" ]; then
				replace_list=$replace_list$LIST_SPACE$replace_pkg
				C_output_error_message   " Replace: $inst_pkg -> $replace_pkg"
			else
				C_output_error_message   " NG: $inst_pkg"
				ERROR_CHECK=1
				err_check=1
			fi
		fi
	done

	echo

	if [ $err_check -eq 0 ]; then
		if [ "$replace_list" != "" ]; then
			INSTALL_PACKAGE=$replace_list
			C_update "${INSTALL_PACKAGE[@]}" "REPLACE"
			C_install_package
			C_install_package_check
		fi
	fi
}


C_install_printer_driver()
{
	C_output_log "Install Printer Driver ($INSTALL_CMD $INSTALL_OPT)" 

	unset DRIVER_PACKAGE
	DRIVER_PACKAGE=`find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE"  | grep -i common`
	if [ "$DRIVER_PACKAGE" != "" ]; then
		$INSTALL_CMD $INSTALL_OPT $DRIVER_PACKAGE
		if [ $? -ne 0 ]; then
			DRIVER_ERROR_CHECK=1
		fi
	fi

	unset DRIVER_PACKAGE
	DRIVER_PACKAGE=`find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE" | grep -v common | grep -v utility`
	$INSTALL_CMD $INSTALL_OPT $DRIVER_PACKAGE
	if [ $? -ne 0 ]; then
		DRIVER_ERROR_CHECK=1
	fi

	unset DRIVER_PACKAGE
	DRIVER_PACKAGE=`find PPD -name "*.$PACKAGE_TYPE" | grep -i cncups`
	if [ "$DRIVER_PACKAGE" != "" ]; then

		$INSTALL_CMD $INSTALL_OPT $DRIVER_PACKAGE
		if [ $? -ne 0 ]; then
			DRIVER_ERROR_CHECK=1
		fi
	fi

	unset DRIVER_PACKAGE
	DRIVER_PACKAGE=`find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE" | grep -i utility`
	if [ "$DRIVER_PACKAGE" != "" ]; then

		$INSTALL_CMD $INSTALL_OPT $DRIVER_PACKAGE
		if [ $? -ne 0 ]; then
			DRIVER_ERROR_CHECK=1
		fi
	fi
	echo
}

#-------------------------------------------------#
# start install.sh
#-------------------------------------------------#
main()
{
	install_package_list=""
	
	#---------------------
	# check directory 
	#---------------------
	C_check_directory

	#---------------------
	# localize
	#---------------------
	if [ -f ${LC_FILE_DIR}/${LC_FILE} ]; then
		source ${LC_FILE_DIR}/${LC_FILE}
	fi

	#---------------
	# check root
	#---------------
	if test `id -un` != "root"; then
		echo -e -n $COLOR_R
		printf "$INST_ERR_01_01" `id -un`
		echo -e -n $COLOR_OFF
		echo
		exit 1
	fi
	
	#---------------------
	# check distribution
	#---------------------
	#C_check_distribution
	
	#------------------------
	# get distribution data
	#------------------------
	case `uname` in
	'SunOS')
		EXE_PATH='/opt/sfw/cups/sbin'
		;;
	'HP-UX')
		EXE_PATH='/usr/sbin:/usr/bin'
		;;
	'AIX')
		EXE_PATH='/usr/sbin:/usr/bin'
		;;
	'Linux')
		EXE_PATH='/usr/sbin:/usr/bin'
		;;
	esac
	
	export PATH=$EXE_PATH:$PATH
	
	if which rpm > /dev/null 2>&1;
	then
		PACKAGE_TYPE="rpm"
		INSTALL_CMD="rpm"
		INSTALL_OPT="-Uvh --replacepkgs"
		if which yum > /dev/null 2>&1;
		then
			INSTALL_PACKAGE_CMD="yum"
		else
			INSTALL_PACKAGE_CMD="dnf"
		fi

		case `uname -m` in 	 
		'i386'|'i686') 	 
			MACHINE_TYPE="i386" 	 
			install_package_list=$INSTALL_PACKAGE_RPM_32
			REPLACE_PACKAGE=$REPLACE_PACKAGE_RPM_32
			;; 	 
		'x86_64') 	 
			MACHINE_TYPE="x86_64" 	 
			install_package_list=$INSTALL_PACKAGE_RPM_64
			REPLACE_PACKAGE=$REPLACE_PACKAGE_RPM_64
			;; 	 
		esac
	else
		PACKAGE_TYPE="deb"
		INSTALL_CMD="dpkg"
		INSTALL_OPT="-i -G --force-overwrite"
		INSTALL_PACKAGE_CMD="apt-get"
	
		case `uname -m` in 	 
		'i386'|'i686') 	 
			MACHINE_TYPE="i386" 	 
			install_package_list=$INSTALL_PACKAGE_DEB_32
			REPLACE_PACKAGE=$REPLACE_PACKAGE_DEB_32
			;; 	 
		'x86_64') 	 
			MACHINE_TYPE="amd64" 	 
			install_package_list=$INSTALL_PACKAGE_DEB_64
			REPLACE_PACKAGE=$REPLACE_PACKAGE_DEB_64

			dpkg --add-architecture i386

			#-------------------------------------
			# Ubuntu only
			#-------------------------------------
			grep -i -e ubuntu /etc/issue > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				if [ -f /etc/lsb-release ]; then
					VER=`grep -i release /etc/lsb-release | sed -e 's/[^0-9]//g'`
					if [ $VER -le 1304 ]; then
						unset install_package_list
						install_package_list=$INSTALL_PACKAGE_DEB_64_IA32
						unset REPLACE_PACKAGE
					fi
				fi
			fi
			;; 	 
		esac
	fi
	
	#------------------------
	# install start
	#------------------------
	C_output_log "Install Start"
	C_output_message "Machine Type = $MACHINE_TYPE"
	C_output_message "Package Type = $PACKAGE_TYPE"
	
	DRIVER_PACKAGE=`find . -name "*$MACHINE_TYPE.$PACKAGE_TYPE" | sort 2> /dev/null`

	#---------------------
	# set driver flag
	#---------------------
	C_set_driver_flag
	
	C_output_message "Package list = "
	
	for list in $DRIVER_PACKAGE
	do
		C_output_message "    $list"
	done
	echo
	
	#---
	C_update "${install_package_list[@]}" "UPDATE"
	for package in $install_package_list
	do
		INSTALL_PACKAGE=$package

		C_check_driver_and_install_package
		if [ "$INSTALL_PACKAGE" = "" ]; then
			continue;
		fi

		C_install_package
		C_install_package_check
	done
	#---

	#---
	#---

	C_install_printer_driver
	C_init_cups restart
}

main $*

if [ $ERROR_CHECK -eq 0 -a $DRIVER_ERROR_CHECK -eq 0 ]
then
	if [ $DRIVER_FLAG -eq 8 ]; then
		MODULE_NAME=cnsetuputilpd
	else
		MODULE_NAME=cnsetuputil
	fi

	if which $MODULE_NAME > /dev/null 2>&1;
	then
		exit 0
	fi
else
	C_output_error_message "$INST_ERR_02_01"
fi

exit 0

