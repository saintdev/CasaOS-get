#!/usr/bin/bash
#
#           CasaOS Update Script v0.4.4-1#
#   GitHub: https://github.com/IceWhaleTech/CasaOS
#   Issues: https://github.com/IceWhaleTech/CasaOS/issues
#   Requires: bash, mv, rm, tr, grep, sed, curl/wget, tar, smartmontools, parted, ntfs-3g, net-tools
# 
#   This script update your CasaOS.
#   Usage:
#
#   	$ wget -qO- https://get.casaos.io/update | bash
#   	  or
#   	$ curl -fsSL https://get.casaos.io/update | bash
#
#   In automated environments, you may want to run as root.
#   If using curl, we recommend using the -fsSL flags.
#
#   This only work on  Linux systems. Please
#   open an issue if you notice any bugs.
#


# shellcheck disable=SC2016
echo '
   _____                 ____   _____ 
  / ____|               / __ \ / ____|
 | |     __ _ ___  __ _| |  | | (___  
 | |    / _` / __|/ _` | |  | |\___ \ 
 | |___| (_| \__ \ (_| | |__| |____) |
  \_____\__,_|___/\__,_|\____/|_____/ 
                                      
   --- Made by IceWhale with YOU ---
'
export PATH=/usr/sbin:$PATH
set -e

###############################################################################
# GOLBALS                                                                     #
###############################################################################

[ "$(id -u)" -ne 0 ] && sudo_cmd="sudo"

# shellcheck source=/dev/null
. /etc/os-release

# SYSTEM REQUIREMENTS
CASA_DEPANDS_PACKAGE="wget"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} smartmontools"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} parted"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} ntfs-3g"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} net-tools"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} udevil"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} samba"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} cifs-utils"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} mergerfs"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} unzip"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} apparmor"
readonly CASA_DEPANDS_PACKAGE
CASA_DEPANDS_COMMAND="wget"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} smartctl"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} parted"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} ntfs-3g"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} netstat"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} udevil"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} samba"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} mount.cifs"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} mount.mergerfs"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} unzip"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} apparmor_status"
readonly CASA_DEPANDS_COMMAND

LSB_DIST=$( ( [ -n "${ID_LIKE}" ] && echo "${ID_LIKE}" ) || ( [ -n "${ID}" ] && echo "${ID}" ) )
readonly LSB_DIST

UNAME_M="$(uname -m)"
readonly UNAME_M


readonly CASA_UNINSTALL_URL="https://get.casaos.io/uninstall/v0.4.4-1"
readonly CASA_UNINSTALL_PATH=/usr/bin/casaos-uninstall

# REQUIREMENTS CONF PATH
# Udevil
readonly UDEVIL_CONF_PATH=/etc/udevil/udevil.conf
readonly DEVMON_CONF_PATH=/etc/conf.d/devmon

# COLORS
readonly COLOUR_RESET='\e[0m'
readonly COLOUR_GREEN='\e[38;5;154m' # green    	| Lines, bullets and separators
readonly COLOUR_WHITE='\e[1m'        # Bold white	| Main descriptions
readonly COLOUR_GREY='\e[90m'        # Grey 		| Credits
readonly COLOUR_RED='\e[91m'         # Red  		| Update notifications Alert
readonly COLOUR_YELLOW='\e[33m'      # Yellow		| Emphasis


# CASAOS VARIABLES
TARGET_ARCH=""
TMP_ROOT=/tmp/casaos-installer
CASA_DOWNLOAD_DOMAIN="https://github.com/"


# PACKAGE LIST OF CASAOS
CASA_SERVICES="casaos-gateway"
CASA_SERVICES="${CASA_SERVICES} casaos-message-bus"
CASA_SERVICES="${CASA_SERVICES} casaos-user-service"
CASA_SERVICES="${CASA_SERVICES} casaos-local-storage"
CASA_SERVICES="${CASA_SERVICES} casaos-app-management"
CASA_SERVICES="${CASA_SERVICES} rclone"
CASA_SERVICES="${CASA_SERVICES} casaos.service"  # must be the last one so update from UI can work


trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}


upgradePath="/var/log/casaos"
upgradeFile="/var/log/casaos/upgrade.log"

if [ -f "$upgradePath" ]; then
    ${sudo_cmd} rm "$upgradePath"
fi

if [ ! -d "$upgradePath" ]; then
    ${sudo_cmd} mkdir -p "$upgradePath"
fi

if [ ! -f "$upgradeFile" ]; then
    ${sudo_cmd} touch "$upgradeFile"
fi

###############################################################################
# Helpers                                                                     #
###############################################################################

#######################################
# Custom printing function
# Globals:
#   None
# Arguments:
#   $1 0:OK   1:FAILED  2:INFO  3:NOTICE
#   message
# Returns:
#   None
#######################################

Show() {
    case $1 in
        0 ) echo -e "- OK $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log;;  # OK
        1 ) # FAILED
            echo -e "- FAILED $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log
            exit 1
            ;;
        2 ) echo -e "- INFO $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log;;  # INFO
        3 ) echo -e "- NOTICE $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log;; # NOTICE
    esac
}

Warn() {
    echo -e "${COLOUR_RED}$1$COLOUR_RESET"
}

GreyStart() {
    echo -e "${COLOUR_GREY}\c"
}

ColorReset() {
    echo -e "$COLOUR_RESET\c"
}

# Check file exists
exist_file() {
    if [ -e "$1" ]; then
        return 1
    else
        return 2
    fi
}

###############################################################################
# FUNCTIONS                                                                   #
###############################################################################

# 0 Get download url domain
# To solve the problem that Chinese users cannot access github.
Get_Download_Url_Domain() {
    # Use ipconfig.io/country and https://ifconfig.io/country_code to get the country code
    REGION=$(${sudo_cmd} wget -q -T 2 ipconfig.io/country || echo "")
    if [ "${REGION}" = "" ]; then
       REGION=$(${sudo_cmd} wget -q -T 2 https://ifconfig.io/country_code || echo "")
    fi
    if [ "${REGION}" = "China" ] || [ "${REGION}" = "CN" ]; then
        CASA_DOWNLOAD_DOMAIN="https://casaos.oss-cn-shanghai.aliyuncs.com/"
    fi
}

# 1 Check Arch
Check_Arch() {
    case $UNAME_M in
    *aarch64*)
        TARGET_ARCH="arm64"
        ;;
    *64*)
        TARGET_ARCH="amd64"
        ;;
    *armv7*)
        TARGET_ARCH="arm-7"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: $UNAME_M"
        exit 1
        ;;
    esac
    Show 0 "Your hardware architecture is : $UNAME_M"
    CASA_PACKAGES="CasaOS-Gateway/releases/download/v0.4.4-1/linux-${TARGET_ARCH}-casaos-gateway-v0.4.4-1.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-MessageBus/releases/download/v0.4.4/linux-${TARGET_ARCH}-casaos-message-bus-v0.4.4.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-UserService/releases/download/v0.4.4/linux-${TARGET_ARCH}-casaos-user-service-v0.4.4.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-LocalStorage/releases/download/v0.4.4/linux-${TARGET_ARCH}-casaos-local-storage-v0.4.4.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-AppManagement/releases/download/v0.4.4-1/linux-${TARGET_ARCH}-casaos-app-management-v0.4.4-1.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS/releases/download/v0.4.4/linux-${TARGET_ARCH}-casaos-v0.4.4.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-CLI/releases/download/v0.4.4/linux-${TARGET_ARCH}-casaos-cli-v0.4.4.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-UI/releases/download/v0.4.4-1/linux-all-casaos-v0.4.4-1.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-AppStore/releases/download/v0.4.4/linux-all-appstore-v0.4.4.tar.gz"
}

# 2 Check Distribution
Check_Distribution() {
    sType=0
    notice=""
    case $LSB_DIST in
    *debian*)
        ;;
    *ubuntu*)
        ;;
    *raspbian*)
        ;;
    *openwrt*)
        Show 1 "Aborted, OpenWrt cannot be installed using this script, please visit ${CASA_OPENWRT_DOCS}."
        exit 1
        ;;
    *alpine*)
        Show 1 "Aborted, Alpine installation is not yet supported."
        USE_SYSTEMD=false
        exit 1
        ;;
    *trisquel*)
        ;;
    *)
        sType=3
        notice="We have not tested it on this system and it may fail to install."
        ;;
    esac
    Show ${sType} "Your Linux Distribution is : ${LSB_DIST} ${notice}"
    if [ "${sType}" = "0" ]; then
        while true; do
            echo -n -e "Y/n: "
            read -r yn
            case $yn in
            [yY][eE][sS] | [yY])
                Show 0 "Distribution check has been ignored."
                break
                ;;
            [nN][oO] | [nN])
                Show 1 "Already exited the installation."
                exit 1
                ;;
            esac
        done
    fi
}

# Check Port Use
Check_Port() {
    TCPListeningnum=$(${sudo_cmd} netstat -an | grep ":$1 " | awk '$1 == "tcp" && $NF == "LISTEN" {print $0}' | wc -l)
    UDPListeningnum=$(${sudo_cmd} netstat -an | grep ":$1 " | awk '$1 == "udp" && $NF == "0.0.0.0:*" {print $0}' | wc -l)
    Listeningnum=$((TCPListeningnum + UDPListeningnum))
    if [ "$Listeningnum" -eq 0 ]; then
        echo "0"
    else
        echo "1"
    fi
}

# Update package

Update_Package_Resource() {
    GreyStart
    if [ -x "$(command -v apk)" ]; then
        ${sudo_cmd} apk update
    elif [ -x "$(command -v apt-get)" ]; then
        ${sudo_cmd} apt-get update
    elif [ -x "$(command -v dnf)" ]; then
        ${sudo_cmd} dnf check-update
    elif [ -x "$(command -v zypper)" ]; then
        ${sudo_cmd} zypper update
    elif [ -x "$(command -v yum)" ]; then
        ${sudo_cmd} yum update
    fi
    ColorReset
}

# Install depends package
Install_Depends() {
    local packagesNeeded

    set -- $CASA_DEPANDS_PACKAGE
    for cmd in $CASA_DEPANDS_COMMAND; do
        if [ ! -x "$(${sudo_cmd} which "$cmd")" ]; then
            packagesNeeded="${packagesNeeded} $1"
        fi
        shift
    done
    Show 2 "Install the necessary dependencies: $packagesNeeded "
    GreyStart
    if [ -x "$(command -v apk)" ]; then
        ${sudo_cmd} apk add --no-cache --virtual casaos-deps "$packagesNeeded"
    elif [ -x "$(command -v apt-get)" ]; then
        ${sudo_cmd} apt-get -y -q install "$packagesNeeded" --no-upgrade
    elif [ -x "$(command -v dnf)" ]; then
        ${sudo_cmd} dnf install "$packagesNeeded"
    elif [ -x "$(command -v zypper)" ]; then
        ${sudo_cmd} zypper install "$packagesNeeded"
    elif [ -x "$(command -v yum)" ]; then
        ${sudo_cmd} yum install "$packagesNeeded"
    elif [ -x "$(command -v pacman)" ]; then
        ${sudo_cmd} pacman -S "$packagesNeeded"
    elif [ -x "$(command -v paru)" ]; then
        ${sudo_cmd} paru -S "$packagesNeeded"
    else
        Show 1 "Package manager not found. You must manually install: $packagesNeeded"
    fi
    ColorReset
}

Check_Dependency_Installation() {
    set -- $CASA_DEPANDS_PACKAGE
    for cmd in ${CASA_DEPANDS_COMMAND}; do
        if [ ! -x "$(${sudo_cmd} which "$cmd")" ]; then
            Show 1 "Dependency \e[33m$packagesNeeded \e[0m installation failed, please try again manually!"
            exit 1
        fi
        shift
    done
}

#Install Rclone
Install_rclone_from_source() {
  ${sudo_cmd} wget -qO ./install.sh https://rclone.org/install.sh
  if [ "${REGION}" = "China" ] || [ "${REGION}" = "CN" ]; then
    sed -i 's/downloads.rclone.org/casaos.oss-cn-shanghai.aliyuncs.com/g' ./install.sh
  else
    sed -i 's/downloads.rclone.org/get.casaos.io/g' ./install.sh
  fi
  ${sudo_cmd} chmod +x ./install.sh
  ${sudo_cmd} ./install.sh || {
    Show 1 "Installation failed, please try again."
    ${sudo_cmd} rm -rf install.sh
    exit 1
  }
  ${sudo_cmd} rm -rf install.sh
  Show 0 "Rclone v1.61.1 installed successfully."
}

Install_Rclone() {
  Show 2 "Install the necessary dependencies: Rclone"
  if [ -x "$(command -v rclone)" ]; then
    version=$(rclone --version 2>>errors | head -n 1)
    target_version="rclone v1.61.1"
    rclone1="${PREFIX}/usr/share/man/man1/rclone.1.gz"
    if [ "$version" != "$target_version" ]; then
      Show 3 "Will change rclone from $version to $target_version."
      rclone_path=$(command -v rclone)
      ${sudo_cmd} rm -rf "${rclone_path}"
      if [ -f "$rclone1" ]; then
        ${sudo_cmd} rm -rf "$rclone1"
      fi
      Install_rclone_from_source
    else
      Show 2 "Target version already installed."
    fi
  else
    Install_rclone_from_source
  fi
  Enable_Service rclone || Show 3 "Service rclone does not exist."
}


Is_Service_Running() {
    if [ "$USE_SYSTEMD" = "true" ]; then
        ${sudo_cmd} systemctl is-active --quiet "${1}.service"
    else
        ${sudo_cmd} "/etc/init.d/${1}" --quiet status
    fi
}

Start_Service() {
    if [ "$USE_SYSTEMD" = "true" ]; then
        ${sudo_cmd} systemctl start "${1}.service"
    else
        ${sudo_cmd} rc-service "${1}" start
    fi
}

Enable_Service() {
    if [ "$USE_SYSTEMD" = "true" ]; then
        ${sudo_cmd} systemctl enable "${1}.service"
    else
        ${sudo_cmd} rc-update add "${1}" default
    fi
}

Stop_Service() {
    if [ "$USE_SYSTEMD" = "true" ]; then
        ${sudo_cmd} systemctl stop "${1}.service"
    else
        ${sudo_cmd} rc-service "${1}" stop
    fi
}

Restart_Service() {
    if [ "$USE_SYSTEMD" = "true" ]; then
        ${sudo_cmd} systemctl restart "${1}.service"
    else
        ${sudo_cmd} rc-service "${1}" restart
    fi
}

Add_User() {
    local args OPTIND

    if [ "$LSB_DIST" = "alpine" ]; then
        while getopts ":Mu:" arg; do
            case "$arg" in
            M)
                args="${args} -H"
                ;;
            u)
                args="${args} -u ${OPTARG}"
                ;;
            *)
                break
                ;;
            esac
        done
        shift $((OPTIND - 1))

        ${sudo_cmd} adduser "${args} $*"
    else
        ${sudo_cmd} useradd "$@"
    fi
}

#Configuration Addons
Configuration_Addons() {
    local svcname
    Show 2 "Configuration CasaOS Addons"
    #Remove old udev rules
    if [ -f "${PREFIX}/etc/udev/rules.d/11-usb-mount.rules" ]; then
        ${sudo_cmd} rm -rf "${PREFIX}/etc/udev/rules.d/11-usb-mount.rules"
    fi

    if [ -f "${PREFIX}/etc/systemd/system/usb-mount@.service" ]; then
        ${sudo_cmd} rm -rf "${PREFIX}/etc/systemd/system/usb-mount@.service"
    fi

    #Udevil
    if [ -f "${PREFIX}${UDEVIL_CONF_PATH}" ]; then

        # Revert previous CasaOS udevil configuration
        #shellcheck disable=SC2016
        ${sudo_cmd} sed -i 's/allowed_media_dirs = \/DATA, \/DATA\/$USER/allowed_media_dirs = \/media, \/media\/$USER, \/run\/media\/$USER/g' "${PREFIX}${UDEVIL_CONF_PATH}"
        ${sudo_cmd} sed -i '/exfat/s/, nonempty//g' "$PREFIX"${UDEVIL_CONF_PATH}
        ${sudo_cmd} sed -i '/default_options/s/, noexec//g' "$PREFIX"${UDEVIL_CONF_PATH}
        ${sudo_cmd} sed -i '/^ARGS/cARGS="--mount-options nosuid,nodev,noatime --ignore-label EFI"' "$PREFIX"${DEVMON_CONF_PATH}

        # GreyStart
        # Add a devmon user
        USERNAME=devmon
        id ${USERNAME} >/dev/null 2>&1 || {
            Add_User -M -u 300 ${USERNAME}
            ${sudo_cmd} passwd -l ${USERNAME}
        }

        if [ "$USE_SYSTEMD" = "true" ]; then
            svcname="devmon@${USERNAME}"
        else
            svcname="devmon"
        fi

        # Add and start Devmon service
        GreyStart
        Enable_Service "$svcname"
        Start_Service "$svcname"
        ColorReset
        # ColorReset
    fi
}

# Download And Install CasaOS
DownloadAndInstallCasaOS() {
    local BASE_URL="https://github.com/IceWhaleTech/"
    if [ -z "${BUILD_DIR}" ]; then

        ${sudo_cmd} mkdir -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory"
        TMP_DIR=$(${sudo_cmd} mktemp -d -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory")

        (
            cd "${TMP_DIR}"

            for PACKAGE in ${CASA_PACKAGES}; do
                Show 2 "Downloading ${PACKAGE}..."

                ${sudo_cmd} wget -t 3 -q -c  "${BASE_URL}${PACKAGE}" || Show 1 "Failed to download package"

            done

            for PACKAGE_FILE in linux-*.tar.gz; do
                Show 2 "Extracting ${PACKAGE_FILE}..."
                ${sudo_cmd} tar zxf "${PACKAGE_FILE}" || Show 1 "Failed to extract package"
            done
        )

        BUILD_DIR=$(realpath -e "${TMP_DIR}"/build || Show 1 "Failed to find build directory")

    fi

    # for SERVICE in ${CASA_SERVICES}; do
    #     Show 2 "Stopping ${SERVICE}..."

    #     Stop_Service "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."

    # done

    MIGRATION_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/migration/script.d || Show 1 "Failed to find migration script directory")

    for MIGRATION_SCRIPT in "${MIGRATION_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${MIGRATION_SCRIPT}..."

        ${sudo_cmd} bash "${MIGRATION_SCRIPT}" || Show 1 "Failed to run migration script"

    done

    Show 2 "Installing CasaOS..."
    SYSROOT_DIR=$(realpath -e "${BUILD_DIR}"/sysroot || Show 1 "Failed to find sysroot directory")

    # Generate manifest for uninstallation
    MANIFEST_FILE=${BUILD_DIR}/sysroot/var/lib/casaos/manifest
    ${sudo_cmd} touch "${MANIFEST_FILE}" || Show 1 "Failed to create manifest file"


    find "${SYSROOT_DIR}" -type f | ${sudo_cmd} cut -c ${#SYSROOT_DIR}- | ${sudo_cmd} cut -c 2- | ${sudo_cmd} tee "${MANIFEST_FILE}" >/dev/null || Show 1 "Failed to create manifest file"

    ${sudo_cmd} cp -rf "${SYSROOT_DIR}"/* / >> /dev/null || Show 1 "Failed to install CasaOS"

    SETUP_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/setup/script.d || Show 1 "Failed to find setup script directory")

    for SETUP_SCRIPT in "${SETUP_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${SETUP_SCRIPT}..."
        ${sudo_cmd} bash "${SETUP_SCRIPT}" || Show 1 "Failed to run setup script"
    done

    # Reset Permissions
    UI_EVENTS_REG_SCRIPT=/etc/casaos/start.d/register-ui-events.sh
    if [ -f "${UI_EVENTS_REG_SCRIPT}" ]; then
        ${sudo_cmd} chmod +x $UI_EVENTS_REG_SCRIPT
    fi

    # Modify app store configuration
    sed -i "/ServerAPI/d" "$PREFIX/etc/casaos/app-management.conf"
    sed -i "/ServerApi/d" "$PREFIX/etc/casaos/app-management.conf"
    sed -i '/appstore/d' "$PREFIX/etc/casaos/app-management.conf"
    sed -i "/server/aappstore = ${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/_appstore/archive/refs/heads/main.zip" "$PREFIX/etc/casaos/app-management.conf"

    #Download Uninstall Script
    if [ -f "${PREFIX}/tmp/casaos-uninstall" ]; then
        ${sudo_cmd} rm -rf "${PREFIX}/tmp/casaos-uninstall"
    fi
    ${sudo_cmd} wget -qO "${PREFIX}/tmp/casaos-uninstall" "$CASA_UNINSTALL_URL"
    ${sudo_cmd} cp -rvf "${PREFIX}/tmp/casaos-uninstall" $CASA_UNINSTALL_PATH || {
        Show 1 "Download uninstall script failed, Please check if your internet connection is working and retry."
        exit 1
    }

    ${sudo_cmd} chmod +x $CASA_UNINSTALL_PATH
    Install_Rclone

    ## Special markings

    Show 0 "CasaOS upgrade successfully"
    for SERVICE in ${CASA_SERVICES}; do
        Show 2 "restart ${SERVICE}..."

        Restart_Service "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."

    done


}

###############################################################################
# Main                                                                        #
###############################################################################

#Usage
usage() {
    cat <<-EOF
		Usage: get.sh [options]
		Valid options are:
		    -p <builddir>           Specify build directory
		    -h                      Show this help message and exit
	EOF
    exit "$1"
}

while getopts ":p:h" arg; do
    case "$arg" in
    p)
        BUILD_DIR=$OPTARG
        ;;
    h)
        usage 0
        ;;
    *)
        usage 1
        ;;
    esac
done

# Step 0: Get Download Url Domain
Get_Download_Url_Domain

# Step 1: Check ARCH
Check_Arch

# Step 2: Install Depends
Update_Package_Resource
Install_Depends
Check_Dependency_Installation


# Step 3: Configuration Addon
Configuration_Addons

# Step 4: Download And Install CasaOS
DownloadAndInstallCasaOS
