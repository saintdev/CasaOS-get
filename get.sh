#!/bin/sh
#
#           CasaOS Installer Script
#
#   GitHub: https://github.com/IceWhaleTech/CasaOS
#   Issues: https://github.com/IceWhaleTech/CasaOS/issues
#   Requires: mv, rm, tr, grep, sed, curl/wget, tar, smartmontools, parted, ntfs-3g, net-tools
#
#   This script installs CasaOS to your system.
#   Usage:
#
#   	$ curl -fsSL https://get.casaos.io | sudo sh
#   	  or
#   	$ wget -qO- https://get.casaos.io | sudo sh
#
#   In automated environments, you may want to run as root.
#   If using curl, we recommend using the -fsSL flags.
#
#   This only work on  Linux systems. Please
#   open an issue if you notice any bugs.
#
clear
echo -e "\e[0m\c"

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

readonly TITLE="CasaOS Installer"

# SYSTEM REQUIREMENTS
readonly MINIMUM_DISK_SIZE_GB="5"
readonly MINIMUM_MEMORY="400"
readonly MINIMUM_DOCKER_VERSION="20"
CASA_DEPANDS_PACKAGE="smartmontools"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} parted"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} ntfs-3g"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} net-tools"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} whiptail" # whiptail is in the newt package on Alpine
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} udevil"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} samba"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} cifs-utils"
readonly CASA_DEPANDS_PACKAGE
CASA_DEPANDS_COMMAND="smartctl"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} parted"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} ntfs-3g"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} netstat"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} whiptail"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} udevil"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} samba"
CASA_DEPANDS_COMMAND="${CASA_DEPANDS_COMMAND} mount.cifs"
readonly CASA_DEPANDS_COMMAND

# SYSTEM INFO
PHYSICAL_MEMORY=$(LC_ALL=C free -m | awk '/Mem:/ { print $2 }')
readonly PHYSICAL_MEMORY

FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_BYTES

readonly FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

LSB_DIST=$( ( [ -n "${ID_LIKE}" ] && echo "${ID_LIKE}" ) || ( [ -n "${ID}" ] && echo "${ID}" ) )
readonly LSB_DIST

UNAME_M="$(uname -m)"
readonly UNAME_M

UNAME_U="$(uname -s)"
readonly UNAME_U

readonly CASA_CONF_PATH=/etc/casaos/gateway.ini
readonly CASA_UNINSTALL_URL="https://raw.githubusercontent.com/IceWhaleTech/get/main/uninstall.sh"
readonly CASA_UNINSTALL_PATH=/usr/bin/casaos-uninstall

# REQUIREMENTS CONF PATH
# Udevil
readonly UDEVIL_CONF_PATH=/etc/udevil/udevil.conf

# COLORS
readonly COLOUR_RESET='\e[0m'
readonly COLOUR_GREEN='\e[38;5;154m' # green    	| Lines, bullets and separators
readonly COLOUR_WHITE='\e[1m'        # Bold white	| Main descriptions
readonly COLOUR_GREY='\e[90m'        # Grey 		| Credits
readonly COLOUR_RED='\e[91m'         # Red  		| Update notifications Alert
readonly COLOUR_YELLOW='\e[33m'      # Yellow		| Emphasis

readonly GREEN_LINE=" ${COLOUR_GREEN}─────────────────────────────────────────────────────$COLOUR_RESET"
readonly GREEN_BULLET=" ${COLOUR_GREEN}-$COLOUR_RESET"
readonly GREEN_SEPARATOR="${COLOUR_GREEN}:$COLOUR_RESET"

# CASAOS VARIABLES
TARGET_ARCH=""
TMP_ROOT=/tmp/casaos-installer

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

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
        0 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_GREEN}  OK  $COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";;  # OK
        1 ) # FAILED
            echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_RED}FAILED$COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2"
            exit 1
            ;;
        2 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_GREEN} INFO $COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";;  # INFO
        3 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_YELLOW}NOTICE$COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";; # NOTICE
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

# Clear Terminal
Clear_Term() {

    # Without an input terminal, there is no point in doing this.
    [ -t 0 ] || return

    clear
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
    CASA_PACKAGES="CasaOS-Gateway/releases/download/v0.3.6/linux-${TARGET_ARCH}-casaos-gateway-v0.3.6.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-UserService/releases/download/v0.3.7/linux-${TARGET_ARCH}-casaos-user-service-v0.3.7.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-LocalStorage/releases/download/v0.3.7-1/linux-${TARGET_ARCH}-casaos-local-storage-v0.3.7-1.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS/releases/download/v0.3.7/linux-${TARGET_ARCH}-casaos-v0.3.7.tar.gz"
    CASA_PACKAGES="${CASA_PACKAGES} CasaOS-UI/releases/download/v0.3.7/linux-all-casaos-v0.3.7.tar.gz"
}

# PACKAGE LIST OF CASAOS (make sure the services are in the right order)
CASA_SERVICES="casaos-gateway"
CASA_SERVICES="${CASA_SERVICES} casaos-user-service"
CASA_SERVICES="${CASA_SERVICES} casaos-local-storage"
CASA_SERVICES="${CASA_SERVICES} casaos" # must be the last one so update from UI can work

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
        sType=1
        notice="We have not tested it on this system and it may fail to install."
        ;;
    esac
    Show $sType "Your Linux Distribution is : $LSB_DIST $notice"
    if [ "$sType" = "1" ]; then
        if (whiptail --title "${TITLE}" --yesno --defaultno "Your Linux Distribution is : $LSB_DIST $notice. Continue installation?" 10 60); then
            Show 0 "Distribution check has been ignored."
        else
            Show 1 "Already exited the installation."
            exit 1
        fi
    fi
}

# 3 Check OS
Check_OS() {
    if echo "$UNAME_U" | grep -q 'Linux'; then
        Show 0 "Your System is : $UNAME_U"
    else
        Show 1 "This script is only for Linux."
        exit 1
    fi
}

# 4 Check Memory
Check_Memory() {
    if [ "${PHYSICAL_MEMORY}" -lt "${MINIMUM_MEMORY}" ]; then
        Show 1 "requires atleast 1GB physical memory."
        exit 1
    fi
    Show 0 "Memory capacity check passed."
}

# 5 Check Disk
Check_Disk() {
    if [ "${FREE_DISK_GB}" -lt "${MINIMUM_DISK_SIZE_GB}" ]; then
        if (whiptail --title "${TITLE}" --yesno --defaultno "Recommended free disk space is greater than ${MINIMUM_DISK_SIZE_GB}GB, Current free disk space is ${FREE_DISK_GB}GB.Continue installation?" 10 60); then
            Show 0 "Disk capacity check has been ignored."
        else
            Show 1 "Already exited the installation."
            exit 1
        fi
    else
        Show 0 "Disk capacity check passed."
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

# Get an available port
Get_Port() {
    CurrentPort=$(${sudo_cmd} cat ${CASA_CONF_PATH} | grep HttpPort | awk '{print $3}')
    if [ "$CurrentPort" = "$Port" ]; then
        # `seq` is not POSIX, but is present in BusyBox ash
        for PORT in $(seq 80 65536); do
            if [ "$(Check_Port "$PORT")" = "0" ]; then
                Port=$PORT
                break
            fi
        done
    else
        Port=$CurrentPort
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
    Show 2 "Install the necessary dependencies: \e[33m$packagesNeeded \e[0m"
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
        Show 1 "Package manager not found. You must manually install: \e[33m$packagesNeeded \e[0m"
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

# Check Docker running
Check_Docker_Running() {
    # `seq` is not POSIX, but is present in BusyBox ash
    for _ in $(seq 1 3); do
        sleep 3
        if Is_Service_Running docker; then
            break
        else
            Show 1 "Docker is not running, try to start"
            Start_Service docker
        fi
    done
}

#Check Docker Installed and version
Check_Docker_Install() {
    if [ -x "$(command -v docker)" ]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [ "$?" -ne 0 ]; then
            Install_Docker
        elif [ "${Docker_Version:0:2}" -lt "${MINIMUM_DOCKER_VERSION}" ]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCKER_VERSION}.xx.xx\e[0m,\Current Docker version is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the CasaOS installation script."
            exit 1
        else
            Show 0 "Current Docker version is ${Docker_Version}."
        fi
    else
        Install_Docker
    fi
}

# Check Docker installed
Check_Docker_Install_Final() {
    if [ -x "$(command -v docker)" ]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [ "$?" -ne 0 ]; then
            Install_Docker
        elif [ "${Docker_Version:0:2}" -lt "${MINIMUM_DOCKER_VERSION}" ]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCKER_VERSION}.xx.xx\e[0m,\Current Docker version is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the CasaOS installation script."
            exit 1
        else
            Show 0 "Current Docker version is ${Docker_Version}."
            Check_Docker_Running
        fi
    else
        Show 1 "Installation failed, please run 'wget -qO - https://get.docker.com | sh' and rerun the CasaOS installation script."
        exit 1
    fi
}

#Install Docker
Install_Docker() {
    Show 2 "Install the necessary dependencies: \e[33mDocker \e[0m"
    GreyStart
    wget -qO - https://get.docker.com | sh
    ColorReset
    if [ "$?" -ne 0 ]; then # FIXME: This doesn't test what you think it does
        Show 1 "Installation failed, please try again."
        exit 1
    else
        Check_Docker_Install_Final
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
    if [ -f "$PREFIX${UDEVIL_CONF_PATH}" ]; then

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
        ${sudo_cmd} rm -rf ${TMP_ROOT}
        mkdir -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory"
        TMP_DIR=$(mktemp -d -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory")

        (
            cd "${TMP_DIR}"

            for PACKAGE in ${CASA_PACKAGES}; do
                Show 2 "Downloading ${PACKAGE}..."
                GreyStart
                wget -q "${BASE_URL}${PACKAGE}" || Show 1 "Failed to download package"
                ColorReset
            done

            for PACKAGE_FILE in linux-*-casaos-*.tar.gz; do
                Show 2 "Extracting ${PACKAGE_FILE}..."
                GreyStart
                tar zxf "${PACKAGE_FILE}" || Show 1 "Failed to extract package"
                ColorReset
            done
        )

        BUILD_DIR=$(realpath -e "${TMP_DIR}"/build || Show 1 "Failed to find build directory")

    fi

    for SERVICE in ${CASA_SERVICES}; do
        Show 2 "Stopping ${SERVICE}..."
        GreyStart
        Stop_Service "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
        ColorReset
    done

    MIGRATION_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/migration/script.d || Show 1 "Failed to find migration script directory")

    for MIGRATION_SCRIPT in "${MIGRATION_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${MIGRATION_SCRIPT}..."
        GreyStart
        ${sudo_cmd} sh "${MIGRATION_SCRIPT}" || Show 1 "Failed to run migration script"
        ColorReset
    done

    Show 2 "Installing CasaOS..."
    SYSROOT_DIR=$(realpath -e "${BUILD_DIR}"/sysroot || Show 1 "Failed to find sysroot directory")

    # Generate manifest for uninstallation
    MANIFEST_FILE=${BUILD_DIR}/sysroot/var/lib/casaos/manifest
    ${sudo_cmd} touch "${MANIFEST_FILE}" || Show 1 "Failed to create manifest file"

    GreyStart
    find "${SYSROOT_DIR}" -type f | ${sudo_cmd} cut -c ${#SYSROOT_DIR}- | ${sudo_cmd} cut -c 2- | ${sudo_cmd} tee "${MANIFEST_FILE}" || Show 1 "Failed to create manifest file"

    ${sudo_cmd} cp -rf "${SYSROOT_DIR}"/* / || Show 1 "Failed to install CasaOS"
    ColorReset

    SETUP_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/setup/script.d || Show 1 "Failed to find setup script directory")

    for SETUP_SCRIPT in "${SETUP_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${SETUP_SCRIPT}..."
        GreyStart
        ${sudo_cmd} sh "${SETUP_SCRIPT}" || Show 1 "Failed to run setup script"
        ColorReset
    done

    #Download Uninstall Script
    if [ -f "$PREFIX/tmp/casaos-uninstall" ]; then
        ${sudo_cmd} rm -rf "$PREFIX/tmp/casaos-uninstall"
    fi
    ${sudo_cmd} wget -qO "$PREFIX/tmp/casaos-uninstall" "$CASA_UNINSTALL_URL"
    ${sudo_cmd} cp -rf "$PREFIX/tmp/casaos-uninstall" $CASA_UNINSTALL_PATH || {
        Show 1 "Download uninstall script failed, Please check if your internet connection is working and retry."
        exit 1
    }

    ${sudo_cmd} chmod +x $CASA_UNINSTALL_PATH

    for SERVICE in ${CASA_SERVICES}; do
        Show 2 "Starting ${SERVICE}..."
        GreyStart
        Start_Service "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
        ColorReset
    done
}

Clean_Temp_Files() {
    Show 2 "Clean temporary files..."
    ${sudo_cmd} rm -rf "${TMP_DIR}" || Show 1 "Failed to clean temporary files"
}

Check_Service_status() {
    for SERVICE in ${CASA_SERVICES}; do
        Show 2 "Checking ${SERVICE}..."
        if Is_Service_Running "${SERVICE}"; then
            Show 0 "${SERVICE} is running."
        else
            Show 1 "${SERVICE} is not running, Please reinstall."
            exit 1
        fi
    done
}

# Get the physical NIC IP
Get_IPs() {
    PORT=$(${sudo_cmd} cat ${CASA_CONF_PATH} | grep port | sed 's/port=//')
    ALL_NIC=$($sudo_cmd ls /sys/class/net/ | grep -v "$(ls /sys/devices/virtual/net/)")
    for NIC in ${ALL_NIC}; do
        IP=$(ip -family inet -oneline addr show dev "${NIC}" | awk '{print $4}' | cut -d/ -f1 | grep -v '127\.0\.0\.1' )
        if [ -n "$IP" ]; then
            if [ "$PORT" -eq "80" ]; then
                echo -e "${GREEN_BULLET} http://$IP (${NIC})"
            else
                echo -e "${GREEN_BULLET} http://$IP:$PORT (${NIC})"
            fi
        fi
    done
}

# Show Welcome Banner
Welcome_Banner() {
    CASA_TAG=$(casaos -v)

    echo -e "${GREEN_LINE}${COLOUR_WHITE}"
    echo -e " CasaOS ${CASA_TAG}${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
    echo -e "${GREEN_LINE}"
    Get_IPs
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${COLOUR_GREY}CasaOS Project  : https://github.com/IceWhaleTech/CasaOS"
    echo -e " ${COLOUR_GREY}CasaOS Team     : https://github.com/IceWhaleTech/CasaOS#maintainers"
    echo -e " ${COLOUR_GREY}CasaOS Discord  : https://discord.gg/knqAbbBbeX"
    echo -e " ${COLOUR_GREY}Website         : https://www.casaos.io"
    echo -e " ${COLOUR_GREY}Online Demo     : http://demo.casaos.io"
    echo -e ""
    echo -e " ${COLOUR_RESET}${COLOUR_WHITE}Uninstall       ${COLOUR_RESET}: casaos-uninstall"
    echo -e "${COLOUR_RESET}"
}

###############################################################################
# Main                                                                        #
###############################################################################

#Usage
usage() {
    cat <<-EOF
		Usage: install.sh [options]
		Valid options are:
		    -p <build_dir>          Specify build directory (Local install)
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

# Step 1：Check ARCH
Check_Arch

# Step 2: Check OS
Check_OS

# Step 3: Check Distribution
Check_Distribution

# Step 4: Check System Required
Check_Memory
Check_Disk

# Step 5: Install Depends
Update_Package_Resource
Install_Depends
Check_Dependency_Installation

# Step 6： Check And Install Docker
Check_Docker_Install

# Step 7: Configuration Addon
Configuration_Addons

# Step 8: Download And Install CasaOS
DownloadAndInstallCasaOS

# Step 9: Check Service Status
Check_Service_status

# Step 10: Show Welcome Banner
#Clear_Term
Welcome_Banner
