#!/bin/bash

export LANG=C

declare -r BLDRED='\e[1;31m' # Red Bold
declare -r BLDGRN='\e[1;32m' # Green Bold
declare -r BLDBLU='\e[1;34m' # Blue Bold
declare -r TXTRST='\e[0m'    # Text Reset

# relative paths
declare -r REL_BUILD_DIR='builddir'
declare -r REL_INSTALL_DIR='installdir'

# absolute paths
declare -r ABS_PREFIX_DEV_DIR='/var/tmp/devcxx'
declare -r BUILDSYSTEM_WORK_DIR="${ABS_PREFIX_DEV_DIR}/cmake"
declare -r PACKAGE_WORK_DIR="${BUILDSYSTEM_WORK_DIR}/SLiM"
declare -r ABS_BUILD_DIR="${PACKAGE_WORK_DIR}/${REL_BUILD_DIR}"
declare -r ABS_SOURCE_DIR="${PWD%\/*}"
declare -r ABS_INSTALL_DIR="${PACKAGE_WORK_DIR}/${REL_INSTALL_DIR}"

# -- -- -- -- -- -- -- -- -- #

function die() {
	printf " ${BLDRED}ERROR${TXTRST}: ${@}\n" >&2
	exit 7
}

function change_directory() {
	if [[ -d "${1}" ]]; then
		cd "${1}" || die "cd failure: ${1}"
	else
		die "directory ${1} does not exist"
	fi
}

function print_help() {
	printf " Known parameters:\n"
	printf " -C|--configure\n"
	printf " -c|--compile\n"
	printf " -i|--install\n"
	printf " -f|--fullclean\n"
}

# -- -- -- -- -- -- -- -- -- #

# parsing command line parameters
while [[ "${#}" -gt 0 ]]; do
	case "${1}" in
		-C|--configure)
			configure=1
		;;
		-c|--compile)
			configure=1
			compile=1
		;;
		-f|--fullclean)
			fullclean=1
		;;
		-h|--help)
			print_help
			exit 0
		;;
		-i|--install)
			configure=1
			compile=1
			install=1
		;;
#		--enable-*)
#			add_cmake_option "${1}" 'true'
#		;;
#		--disable-*)
#			add_cmake_option "${1}" 'false'
#		;;
		*)
			print_help
			die "unknown parameter: ${1}"
		;;
	esac
	shift
done

# -- -- -- -- -- -- -- -- -- #

function clean_action() {
	printf "${BLDRED}CLEANING WITH CMAKE${TXTRST}\n"

	function safe_remove_dir() {
		printf "removing « ${1} » directory ... "
		if [[ -d "${1}" ]]; then
			rm -rf "${1}" &> /dev/null
			if [[ $? -eq 0 ]]; then
				printf "${BLDBLU}[${BLDGRN}ok${BLDBLU}]${TXTRST}\n"
			else
				printf "${BLDBLU}[${BLDRED}ko${BLDBLU}]${TXTRST}\n"
			fi
		else
			printf "${BLDBLU}[${BLDRED}not found${BLDBLU}]${TXTRST}\n"
		fi
	}

	if [[ -d "${PACKAGE_WORK_DIR}" ]]; then
		change_directory "${PACKAGE_WORK_DIR}"

		safe_remove_dir "${REL_BUILD_DIR}"
		safe_remove_dir "${REL_INSTALL_DIR}"
	fi
}

function configure_action() {
	printf "${BLDRED}CONFIGURING WITH CMAKE${TXTRST}\n"

	local -r CPPFLAGS="-pipe -march=x86-64 -mtune=generic -O2 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -Wformat=2 -Wfatal-errors"

	mkdir -p "${ABS_BUILD_DIR}"
	change_directory "${ABS_BUILD_DIR}"

	# Prepare override rules (set valid compiler, append CPPFLAGS etc.)
	local -r build_rules=${ABS_BUILD_DIR}/SLiM_rules.cmake

	cat > "${build_rules}" <<- _EOF_ || die
		set(CMAKE_C_COMPILE_OBJECT "gcc <DEFINES> <INCLUDES> ${CPPFLAGS} <FLAGS> -o <OBJECT> -c <SOURCE>" CACHE STRING "C compile command" FORCE)
		set(CMAKE_CXX_COMPILE_OBJECT "g++ <DEFINES> <INCLUDES> ${CPPFLAGS} <FLAGS> -o <OBJECT> -c <SOURCE>" CACHE STRING "C++ compile command" FORCE)
	_EOF_

	local PF='SLiM'
	local common_config=${ABS_BUILD_DIR}/SLiM.cmake
	local libdir='lib64'
	cat > "${common_config}" <<- _EOF_ || die
		set(LIB_SUFFIX ${libdir/lib} CACHE STRING "library path suffix" FORCE)
		set(CMAKE_INSTALL_LIBDIR ${libdir} CACHE PATH "Output directory for libraries")
		set(CMAKE_INSTALL_INFODIR "/usr/share/info" CACHE PATH "")
		set(CMAKE_INSTALL_MANDIR "/usr/share/man" CACHE PATH "")
		set(CMAKE_INSTALL_DOCDIR "/usr/share/doc/${PF}" CACHE PATH "")
		set(CMAKE_USER_MAKE_RULES_OVERRIDE "${build_rules}" CACHE FILEPATH "SLiM override rules")
		set(BUILD_SHARED_LIBS ON CACHE BOOL "")
		set(CMAKE_COMPILE_WARNING_AS_ERROR OFF CACHE BOOL "")
	_EOF_

	local cmakeargs=(
		-C "${common_config}"
		-G "Unix Makefiles"
		-DUSE_PAM=yes
		-DUSE_CONSOLEKIT=OFF
		-DBUILD_SLIMLOCK=yes
		-DCMAKE_INSTALL_PREFIX="/usr"
	)
	cmake "${cmakeargs[@]}" ${ABS_SOURCE_DIR}
}

function compile_action() {
	printf "${BLDRED}BUILDING WITH CMAKE${TXTRST}\n"

	change_directory "${ABS_BUILD_DIR}"
	cmake --build . || die "compile failure"
}

function install_action() {
	printf "${BLDRED}INSTALLING WITH CMAKE${TXTRST}\n"

	change_directory "${ABS_BUILD_DIR}"
	mkdir -p "${ABS_INSTALL_DIR}"
	DESTDIR="${ABS_INSTALL_DIR}" cmake --install . || die "install failure"
}

# -- -- -- -- -- -- -- -- -- #

if [[ ${fullclean} -eq 1 ]]; then
	clean_action
fi

if [[ ${configure} -eq 1 ]]; then
	configure_action
fi

if [[ ${compile} -eq 1 ]]; then
	compile_action
fi

if [[ ${install} -eq 1 ]]; then
	install_action
fi

# -- -- -- -- -- -- -- -- -- #
