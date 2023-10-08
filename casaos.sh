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
#   	$ curl -fsSL https://get.casaos.io | sh
#   	  or
#   	$ wget -qO- https://get.casaos.io | sh
#
#   In automated environments, you may want to run as root.
#   If using curl, we recommend using the -fsSL flags.
#
#   This only work on  Linux systems. Please
#   open an issue if you notice any bugs.
#

clear

echo '
   _____                 ____   _____ 
  / ____|               / __ \ / ____|
 | |     __ _ ___  __ _| |  | | (___  
 | |    / _` / __|/ _` | |  | |\___ \ 
 | |___| (_| \__ \ (_| | |__| |____) |
  \_____\__,_|___/\__,_|\____/|_____/ 
                                      
   --- Made by IceWhale with YOU ---
'

###############################################################################
# Golbals                                                                     #
###############################################################################

# Not every platform has or needs sudo (https://termux.com/linux.html)
[ "$(id -u)" -ne 0 ] && sudo_cmd="sudo"

readonly TITLE="CasaOS Installer"
# SYSTEM REQUIREMENTS
readonly MINIMUM_DISK_SIZE_GB="5"
readonly MINIMUM_MEMORY="400"
readonly MINIMUM_DOCER_VERSION="20"
readonly SUPPORTED_DIST='debian ubuntu raspbian'
CASA_DEPANDS_PACKAGE="smartmontools"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} parted"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} ntfs-3g"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} net-tools"
CASA_DEPANDS_PACKAGE="${CASA_DEPANDS_PACKAGE} whiptail" # In Alpine whiptail is provided by the newt package
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
readonly PHYSICAL_MEMORY=$(LC_ALL=C free -m | awk '/Mem:/ { print $2 }')
readonly FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_GB=$((${FREE_DISK_BYTES} / 1024 / 1024))
readonly LSB_DIST="$(. /etc/os-release && echo "$ID")"
readonly LSB_DIST_LIKE="$(. /etc/os-release && echo "$ID_LIKE")"
readonly UNAME_M="$(uname -m)"
readonly UNAME_U="$(uname -s)"

# CasaOS PATHS
readonly CASA_REPO=IceWhaleTech/CasaOS
readonly CASA_UNZIP_TEMP_FOLDER=/tmp/casaos
readonly CASA_BIN=casaos
readonly CASA_BIN_PATH=/usr/bin/casaos
readonly CASA_CONF_PATH=/etc/casaos.conf
readonly CASA_SERVICE_PATH=/etc/systemd/system/casaos.service
readonly CASA_HELPER_PATH=/usr/share/casaos/shell/
readonly CASA_USER_CONF_PATH=/var/lib/casaos/conf/
readonly CASA_DB_PATH=/var/lib/casaos/db/
readonly CASA_TEMP_PATH=/var/lib/casaos/temp/
readonly CASA_LOGS_PATH=/var/log/casaos/
readonly CASA_PACKAGE_EXT=".tar.gz"
readonly CASA_RELEASE_API="https://api.github.com/repos/${CASA_REPO}/releases"
readonly CASA_OPENWRT_DOCS="https://github.com/IceWhaleTech/CasaOS-OpenWrt"
readonly CASA_UNINSTALL_URL="https://raw.githubusercontent.com/IceWhaleTech/get/main/casaos-uninstall"
readonly CASA_VERSION_URL="https://api.casaos.io/casaos-api/version"
readonly CASA_UNINSTALL_PATH=/usr/bin/casaos-uninstall

# DEPANDS CONF PATH
readonly UDEVIL_CONF_PATH=/etc/udevil/udevil.conf

readonly COLOUR_RESET='\e[0m'
readonly COLOUR_GREEN='\e[38;5;154m' # green    	| Lines, bullets and separators
readonly COLOUR_WHITE='\e[1m'        # Bold white	| Main descriptions
readonly COLOUR_GREY='\e[90m'        # Grey 		| Credits
readonly COLOUR_RED='\e[91m'         # Red  		| Update notifications Alert
readonly COLOUR_YELLOW='\e[33m'      # Yellow		| Emphasis

readonly GREEN_LINE=" ${COLOUR_GREEN}─────────────────────────────────────────────────────$COLOUR_RESET"
readonly GREEN_BULLET=" ${COLOUR_GREEN}-$COLOUR_RESET"
readonly GREEN_SEPARATOR="${COLOUR_GREEN}:$COLOUR_RESET"
readonly PASSED="${COLOUR_GREEN}PASSED$COLOUR_RESET"

Port=80
Target_Arch=""
Target_Distro="debian"
Target_OS="linux"
Casa_Tag=""

USE_SYSTEMD=true

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

###############################################################################
# Helpers                                                                     #
###############################################################################

#Usage
usage() {
    cat <<-EOF
		Usage: get.sh [options]
		Valid options are:
		    -v <version>            Specify version to install For example: get.sh -v v0.2.3 | get.sh -v pre | get.sh
		    -h                      Show this help message and exit
	EOF
    exit $1
}

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
        1 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_RED}FAILED$COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";;    # FAILED
        2 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_GREEN} INFO $COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";;  # INFO
        3 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_YELLOW}NOTICE$COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";; # NOTICE
    esac
}

Warn() {
    echo -e "${COLOUR_RED}$1$COLOUR_RESET"
}

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

# 0 Check_exist
Check_Exist() {
    #Create Dir
    Show 2 "Create folders."
    ${sudo_cmd} mkdir -p ${CASA_HELPER_PATH}
    ${sudo_cmd} mkdir -p ${CASA_LOGS_PATH}
    ${sudo_cmd} mkdir -p ${CASA_USER_CONF_PATH}
    ${sudo_cmd} mkdir -p ${CASA_DB_PATH}
    ${sudo_cmd} mkdir -p ${CASA_TEMP_PATH}

    if Is_Service_Running "${CASA_BIN}"; then
        Stop_Service ${CASA_BIN}
        Disable_Service ${CASA_BIN}
    fi
    Show 2 "Start cleaning up the old version."
    if [ -f "/usr/lib/systemd/system/casaos.service" ]; then
        ${sudo_cmd} rm -rf /usr/lib/systemd/system/casaos.service
    fi

    if [ -f "/lib/systemd/system/casaos.service" ]; then
        ${sudo_cmd} rm -rf /lib/systemd/system/casaos.service
    fi

    if [ -f "/usr/local/bin/${CASA_BIN}" ]; then
        ${sudo_cmd} rm -rf /usr/local/bin/${CASA_BIN}
    fi

    if [ -f "/casaOS/server/conf/conf.ini" ]; then
        ${sudo_cmd} cp -rf /casaOS/server/conf/conf.ini ${CASA_CONF_PATH}
        exist_file /casaOS/server/conf/*.json
        value=$?
        if [ $value -eq 1 ]; then
            ${sudo_cmd} cp -rf /casaOS/server/conf/*.json ${CASA_USER_CONF_PATH}
        fi
    fi

    if [ -d "/casaOS/server/db" ]; then
        ${sudo_cmd} cp -rf /casaOS/server/db/* ${CASA_DB_PATH}
    fi

    if [ -f ${CASA_UNINSTALL_PATH} ]; then
        ${sudo_cmd} rm -rf ${CASA_UNINSTALL_PATH}
    fi

    #Clean
    if [ -d "/casaOS" ]; then
        ${sudo_cmd} rm -rf /casaOS
    fi
    Show 0 "Clearance completed."

}

# 1 Check Arch
Check_Arch() {
    case $UNAME_M in
    *aarch64*)
        Target_Arch="arm64"
        ;;
    *64*)
        Target_Arch="amd64"
        ;;
    *armv7*)
        Target_Arch="arm-7"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: $UNAME_M"
        exit 1
        ;;
    esac
    Show 0 "Your hardware architecture is : $UNAME_M"
}

# 2 Check Distribution
Check_Distribution() {
    sType=0
    notice=""
    case $LSB_DIST in
    *debian*)
        Target_Distro="debian"
        ;;
    *ubuntu*)
        Target_Distro="ubuntu"
        ;;
    *raspbian*)
        Target_Distro="raspbian"
        ;;
    *openwrt*)
        Show 1 "Aborted, OpenWrt cannot be installed using this script, please visit ${CASA_OPENWRT_DOCS}."
        exit 1
        ;;
    *alpine*)
        Show 1 "Aborted, Alpine installation is not yet supported."
        Target_Distro="alpine"
        USE_SYSTEMD=false
        exit 1
        ;;
    *trisquel*)
        Target_Distro="debian"
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
        Target_OS="linux"
        Show 0 "Your System is : $UNAME_U"
    else
        Show 1 "Aborted, Support Linux system only."
        exit 1
    fi
}

# Check Memory
Check_Memory() {
    if [ "${PHYSICAL_MEMORY}" -lt "${MINIMUM_MEMORY}" ]; then
        Show 1 "requires atleast 1GB physical memory."
        exit 1
    fi
    Show 0 "Memory capacity check passed."
}

# Check Disk

Check_Disk() {
    if [ "${FREE_DISK_GB}" -lt "${MINIMUM_DISK_SIZE_GB}" ]; then
        if (whiptail --title "${TITLE}" --yesno --defaultno "Recommended free disk space is greater than \e[33m${MINIMUM_DISK_SIZE_GB}GB\e[0m, Current free disk space is \e[33m${FREE_DISK_GB}GB.Continue installation?" 10 60); then
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
    echo -e "${COLOUR_RESET}\c"
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

Disable_Service() {
    if [ "$USE_SYSTEMD" = "true" ]; then
        ${sudo_cmd} systemctl disable "${1}.service"
    else
        ${sudo_cmd} rc-update del "${1}"
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

# Check Docker installed
Check_Docker_Install_Final() {
    if [ -x "$(command -v docker)" ]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [ "$?" -ne 0 ]; then
            Install_Docker
        elif [ "${Docker_Version:0:2}" -lt "${MINIMUM_DOCER_VERSION}" ]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCER_VERSION}.xx.xx\e[0m,\Current Docker verison is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the CasaOS installation script."
            exit 1
        else
            Show 0 "Current Docker verison is ${Docker_Version}."
            Check_Docker_Running
        fi
    else
        Show 1 "Installation failed, please run 'wget -qO - https://get.docker.com | sh' and rerun the CasaOS installation script."
        exit 1
    fi
}

#Install Docker
Install_Docker() {
    Show 0 "Docker will be installed automatically."
    echo -e "${COLOUR_GREY}\c"
    wget -qO - https://get.docker.com | sh
    echo -e "${COLOUR_RESET}\c"
    if [ "$?" -ne 0 ]; then # FIXME: This doesn't test what you think it does
        Show 1 "Installation failed, please try again."
        exit 1
    else
        Check_Docker_Install_Final
    fi
}

#Check Docker Installed and version
Check_Docker_Install() {
    if [ -x "$(command -v docker)" ]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [ "$?" -ne 0 ]; then
            Install_Docker
        elif [ "${Docker_Version:0:2}" -lt "${MINIMUM_DOCER_VERSION}" ]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCER_VERSION}.xx.xx\e[0m,\Current Docker verison is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the CasaOS installation script."
            exit 1
        else
            Show 0 "Current Docker verison is ${Docker_Version}."
        fi
    else
        Install_Docker
    fi
}

#Download CasaOS Package
Download_CasaOS() {
    Show 2 "Downloading CasaOS for ${Target_OS}/${Target_Arch}..."
    Net_Getter="wget -qO -"
    Casa_Package="${Target_OS}-${Target_Arch}-casaos${CASA_PACKAGE_EXT}"
    if [ ! -n "$version" ]; then
        Casa_Tag="v$(${Net_Getter} ${CASA_VERSION_URL})"
    elif [ "$version" = "pre" ]; then
        Casa_Tag="$(${net_getter} ${CASA_RELEASE_API} | grep -o '"tag_name": ".*"' | sed 's/"//g' | sed 's/tag_name: //g' | sed -n '1p')"
    else
        Casa_Tag="$version"
    fi
    Casa_Package_URL="https://github.com/${CASA_REPO}/releases/download/${Casa_Tag}/${Casa_Package}"
    # Remove Temp File
    ${sudo_cmd} rm -rf "$PREFIX/tmp/${Casa_Package}"
    # Download Package
    ${sudo_cmd} ${Net_Getter} "${Casa_Package_URL}" >"$PREFIX/tmp/${Casa_Package}"
    if [ "$?" -ne 0 ]; then
        Show 1 "Download failed, Please check if your internet connection is working and retry."
        exit 1
    else
        Show 0 "Download successful!"
    fi
    #Extract CasaOS Package
    Show 2 "Extracting..."
    case "${Casa_Package}" in
    *.zip) ${sudo_cmd} unzip -o "$PREFIX/tmp/${Casa_Package}" -d "$PREFIX/tmp/" ;;
    *.tar.gz) ${sudo_cmd} tar -xzf "$PREFIX/tmp/${Casa_Package}" -C "$PREFIX/tmp/" ;;
    esac
    #Setting Executable Permissions
    ${sudo_cmd} chmod +x "$PREFIX${CASA_UNZIP_TEMP_FOLDER}/${CASA_BIN}"

    #Download Uninstall Script
    if [ -f "$PREFIX/tmp/casaos-uninstall" ]; then
        ${sudo_cmd} rm -rf $PREFIX/tmp/casaos-uninstall
    fi
    ${sudo_cmd} ${Net_Getter} "$CASA_UNINSTALL_URL" >"$PREFIX/tmp/casaos-uninstall"
    ${sudo_cmd} cp -rf "$PREFIX/tmp/casaos-uninstall" $CASA_UNINSTALL_PATH
    if [ "$?" -ne 0 ]; then
        Show 1 "Download uninstall script failed, Please check if your internet connection is working and retry."
        exit 1
    fi
    ${sudo_cmd} chmod +x $CASA_UNINSTALL_PATH

}

#Install Addons
Install_Addons() {
    Show 2 "Installing CasaOS Addons"
    # ${sudo_cmd} cp -rf "$PREFIX${CASA_UNZIP_TEMP_FOLDER}/shell/11-usb-mount.rules" "/etc/udev/rules.d/"
    # ${sudo_cmd} cp -rf "$PREFIX${CASA_UNZIP_TEMP_FOLDER}/shell/usb-mount@.service" "/etc/systemd/system/"
    sync
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

        #Change udevil mount dir to /DATA
        ${sudo_cmd} sed -i 's/allowed_media_dirs = \/media\/$USER, \/run\/media\/$USER/allowed_media_dirs = \/DATA, \/DATA\/$USER/g' $PREFIX${UDEVIL_CONF_PATH}

        # Add a devmon user
        Add_User -M -u 300 devmon
        ${sudo_cmd} passwd -l devmon

        if [ "$USE_SYSTEMD" = "true" ]; then
            svcname="devmon@devmon"
        else
            svcname="devmon"
        fi

        # Add and start Devmon service
        Enable_Service "$svcname"
        Start_Service "$svcname"
    fi
}

#Clean Temp Files
Clean_Temp_Files() {
    Show 0 "Clean..."
    ${sudo_cmd} rm -rf "$PREFIX${CASA_UNZIP_TEMP_FOLDER}"
    sync
}

#Install CasaOS
Install_CasaOS() {
    Show 2 "Installing..."

    # Install Bin
    ${sudo_cmd} mv -f $PREFIX${CASA_UNZIP_TEMP_FOLDER}/${CASA_BIN} ${CASA_BIN_PATH}

    # Install Helper
    if [ -d "${CASA_HELPER_PATH}" ]; then
        ${sudo_cmd} rm -rf ${CASA_HELPER_PATH}*
    fi
    ${sudo_cmd} cp -rf $PREFIX${CASA_UNZIP_TEMP_FOLDER}/shell/* ${CASA_HELPER_PATH}
    #Setting Executable Permissions
    ${sudo_cmd} chmod +x $PREFIX${CASA_HELPER_PATH}*

    # Install Conf
    if [ ! -f "$PREFIX${CASA_CONF_PATH}" ]; then
        if [ -f "$PREFIX${CASA_UNZIP_TEMP_FOLDER}/conf/conf.ini.sample" ]; then
            ${sudo_cmd} mv -f $PREFIX${CASA_UNZIP_TEMP_FOLDER}/conf/conf.ini.sample ${CASA_CONF_PATH}
        else
            ${sudo_cmd} mv -f $PREFIX${CASA_UNZIP_TEMP_FOLDER}/conf/conf.conf.sample ${CASA_CONF_PATH}
        fi

    fi
    sync

    if [ ! -x "$(command -v ${CASA_BIN})" ]; then
        Show 1 "Installation failed, please try again."
        exit 1
    else
        Show 0 "CasaOS Successfully installed."
    fi
}

#Generate Service File
Generate_Service() {
    if [ -f ${CASA_SERVICE_PATH} ]; then
        Show 2 "Try stop CasaOS system service."
        # Stop before generation
        if Is_Service_Running "${CASA_BIN}"; then
            Stop_Service ${CASA_BIN}
        fi
    fi
    Show 2 "Create system service for CasaOS."

    ${sudo_cmd} tee ${CASA_SERVICE_PATH} >/dev/null <<EOF
				[Unit]
				Description=CasaOS Service
				StartLimitIntervalSec=0

				[Service]
				Type=simple
				LimitNOFILE=15210
				Restart=always
				RestartSec=1
				User=root
				ExecStart=${CASA_BIN_PATH} -c ${CASA_CONF_PATH}

				[Install]
				WantedBy=multi-user.target
EOF
    Show 0 "CasaOS service Successfully created."
}

# Start CasaOS
Start_CasaOS() {
    #Get an available port
    Get_Port
    #Replace Port
    ${sudo_cmd} sed -i "s/^HttpPort =.*/HttpPort = ${Port}/g" ${CASA_CONF_PATH}

    Show 2 "Create a system startup service for CasaOS."
    if [ "${USE_SYSTEMD}" = "true" ]; then
        $sudo_cmd systemctl daemon-reload
    fi
    Enable_Service "${CASA_BIN}"

    Show 2 "Start CasaOS service."
    Start_Service "${CASA_BIN}"

    if Is_Service_Running "${CASA_BIN}"; then
        Show 0 "Service started successfully."
    else
        Show 1 "Failed to start, please try again."
        exit 1
    fi
}
# Get the physical NIC IP
Get_IPs() {
    All_NIC=$($sudo_cmd ls /sys/class/net/ | grep -v "$(ls /sys/devices/virtual/net/)")
    for NIC in ${All_NIC}; do
        Ip=$(ip -family inet -oneline addr show dev "${NIC}" | awk '{print $4}' | cut -d/ -f1 | grep -v '127\.0\.0\.1' )
        if [ -n "$Ip" ]; then
            if [ "$Port" -eq "80" ]; then
                echo -e "${GREEN_BULLET} http://$Ip (${NIC})"
            else
                echo -e "${GREEN_BULLET} http://$Ip:$Port (${NIC})"
            fi
        fi
    done
}

# Show Welcome Banner
Welcome_Banner() {
    echo -e "${GREEN_LINE}${COLOUR_WHITE}"
    echo -e " CasaOS ${Casa_Tag}${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
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

while getopts ":v:h" arg; do
    case "$arg" in
    v)
        version=$OPTARG
        ;;
    h)
        usage 0
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

# Step 7: Download CasaOS
Check_Exist
Download_CasaOS

# Step 8: Install Addon
Install_Addons

# Step 8.1: Configuration Addon
Configuration_Addons

# Step 9: Install CasaOS
Install_CasaOS

# Step 10: Generate_Service
Generate_Service

# Step 11: Start CasaOS
Start_CasaOS
Clean_Temp_Files

# Step 12: Welcome
Clear_Term
Welcome_Banner

#-----------------------------------------------------------------------------------
exit 0
#-----------------------------------------------------------------------------------
