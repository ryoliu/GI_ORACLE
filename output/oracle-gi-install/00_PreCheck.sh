#!/bin/bash

set -e
set -u
set -o pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/GI_Setup.conf"
WARNING_COUNT=0

pass() {
    printf "${GREEN}PASS: %s${NC}\n" "$1"
}

warn() {
    printf "${YELLOW}WARNING: %s${NC}\n" "$1"
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

fail() {
    printf "${RED}ERROR: %s${NC}\n" "$1"
    exit 1
}

require_value() {
    if [ -z "$2" ] || [ "$2" = "CHANGE_ME" ]; then
        fail "$1 is not configured in GI_Setup.conf."
    fi
}

version_at_least() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

check_group() {
    if getent group "$1" > /dev/null; then
        pass "Group exists: $1"
    else
        warn "Group is missing and must be created by 01_PreInstall.sh: $1"
    fi
}

check_user() {
    USER_NAME="$1"
    PRIMARY_GROUP="$2"

    if ! id "$USER_NAME" > /dev/null 2>&1; then
        warn "User is missing and must be created by 01_PreInstall.sh: $USER_NAME"
        return
    fi

    CURRENT_PRIMARY_GROUP=$(id -gn "$USER_NAME")
    if [ "$CURRENT_PRIMARY_GROUP" != "$PRIMARY_GROUP" ]; then
        fail "$USER_NAME primary group is $CURRENT_PRIMARY_GROUP; expected $PRIMARY_GROUP."
    fi

    pass "User exists with the expected primary group: $USER_NAME"
}

check_membership() {
    USER_NAME="$1"
    GROUP_NAME="$2"

    if ! id "$USER_NAME" > /dev/null 2>&1; then
        return
    fi

    if id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx "$GROUP_NAME"; then
        pass "$USER_NAME belongs to $GROUP_NAME."
    else
        warn "$USER_NAME must be added to $GROUP_NAME by 01_PreInstall.sh."
    fi
}

check_directory() {
    DIRECTORY_PATH="$1"
    EXPECTED_OWNER="$2"
    EXPECTED_GROUP="$3"

    if [ ! -e "$DIRECTORY_PATH" ]; then
        warn "Directory is missing and must be created by 01_PreInstall.sh: $DIRECTORY_PATH"
        return
    fi

    if [ ! -d "$DIRECTORY_PATH" ]; then
        fail "Path exists but is not a directory: $DIRECTORY_PATH"
    fi

    CURRENT_OWNER=$(stat -c '%U' "$DIRECTORY_PATH")
    CURRENT_GROUP=$(stat -c '%G' "$DIRECTORY_PATH")

    if [ "$CURRENT_OWNER" != "$EXPECTED_OWNER" ] || [ "$CURRENT_GROUP" != "$EXPECTED_GROUP" ]; then
        fail "$DIRECTORY_PATH owner is $CURRENT_OWNER:$CURRENT_GROUP; expected $EXPECTED_OWNER:$EXPECTED_GROUP."
    fi

    pass "Directory owner is correct: $DIRECTORY_PATH"
}

check_sysctl_minimum() {
    PARAMETER_NAME="$1"
    MINIMUM_VALUE="$2"
    CURRENT_VALUE=$(sysctl -n "$PARAMETER_NAME" 2>/dev/null || true)

    if [ -z "$CURRENT_VALUE" ]; then
        warn "$PARAMETER_NAME is not available."
    elif [ "$CURRENT_VALUE" -lt "$MINIMUM_VALUE" ]; then
        warn "$PARAMETER_NAME is $CURRENT_VALUE; 01_PreInstall.sh must set at least $MINIMUM_VALUE."
    else
        pass "$PARAMETER_NAME = $CURRENT_VALUE"
    fi
}

printf '%s\n' "=== Oracle GI / Database PreCheck ==="

# 1. Execution account and configuration
printf '%s\n' "=== Check execution account and configuration ==="

if [ "$(id -u)" -ne 0 ]; then
    fail "This script must be run as root."
fi

pass "Running as root."

if [ ! -f "$CONFIG_FILE" ]; then
    fail "Configuration file not found: $CONFIG_FILE"
fi

if ! source "$CONFIG_FILE"; then
    fail "Unable to load configuration file: $CONFIG_FILE"
fi

require_value "ENVIRONMENT" "${ENVIRONMENT:-}"
require_value "ALLOW_UNSUPPORTED_19_3_BASE" "${ALLOW_UNSUPPORTED_19_3_BASE:-}"
require_value "OS_FAMILY" "${OS_FAMILY:-}"
require_value "OS_MAJOR_VERSION" "${OS_MAJOR_VERSION:-}"
require_value "HOST_NAME" "${HOST_NAME:-}"
require_value "ORA_INVENTORY" "${ORA_INVENTORY:-}"
require_value "OINSTALL_GROUP" "${OINSTALL_GROUP:-}"
require_value "GRID_OWNER" "${GRID_OWNER:-}"
require_value "GRID_PRIMARY_GROUP" "${GRID_PRIMARY_GROUP:-}"
require_value "GRID_BASE" "${GRID_BASE:-}"
require_value "GRID_HOME" "${GRID_HOME:-}"
require_value "GI_BASE_VERSION" "${GI_BASE_VERSION:-}"
require_value "GI_SOFTWARE" "${GI_SOFTWARE:-}"
require_value "ASM_OSDBA_GROUP" "${ASM_OSDBA_GROUP:-}"
require_value "ASM_OSASM_GROUP" "${ASM_OSASM_GROUP:-}"
require_value "ASM_DISCOVERY_STRING" "${ASM_DISCOVERY_STRING:-}"
require_value "ASM_DISKGROUP_DATA_DISKS" "${ASM_DISKGROUP_DATA_DISKS:-}"
require_value "ASM_DISKGROUP_FRA_DISKS" "${ASM_DISKGROUP_FRA_DISKS:-}"
require_value "ORACLE_OWNER" "${ORACLE_OWNER:-}"
require_value "ORACLE_PRIMARY_GROUP" "${ORACLE_PRIMARY_GROUP:-}"
require_value "ORACLE_BASE" "${ORACLE_BASE:-}"
require_value "DB_OSDBA_GROUP" "${DB_OSDBA_GROUP:-}"
require_value "DB_OSRACDBA_GROUP" "${DB_OSRACDBA_GROUP:-}"
require_value "DB_HOME" "${DB_HOME:-}"
require_value "DB_BASE_VERSION" "${DB_BASE_VERSION:-}"
require_value "DB_SOFTWARE" "${DB_SOFTWARE:-}"

UNSUPPORTED_BASE_MODE="NO"

if [ "$ALLOW_UNSUPPORTED_19_3_BASE" = "YES" ]; then
    if [ "$ENVIRONMENT" != "PERSONAL_LAB" ]; then
        fail "Unsupported Base-only mode is allowed only for PERSONAL_LAB."
    fi

    UNSUPPORTED_BASE_MODE="YES"
    warn "Oracle 19.3 Base without RU is not supported on Oracle Linux 9."
elif [ "$ALLOW_UNSUPPORTED_19_3_BASE" = "NO" ]; then
    require_value "GI_RU_VERSION" "${GI_RU_VERSION:-}"
    require_value "GI_RU" "${GI_RU:-}"
    require_value "GI_OPATCH_VERSION" "${GI_OPATCH_VERSION:-}"
    require_value "GI_OPATCH" "${GI_OPATCH:-}"
    require_value "DB_RU_VERSION" "${DB_RU_VERSION:-}"
    require_value "DB_RU" "${DB_RU:-}"
    require_value "DB_OPATCH_VERSION" "${DB_OPATCH_VERSION:-}"
    require_value "DB_OPATCH" "${DB_OPATCH:-}"
else
    fail "ALLOW_UNSUPPORTED_19_3_BASE must be YES or NO."
fi

pass "Required configuration values are present."

# 2. Platform compatibility
printf '%s\n' "=== Check platform compatibility ==="

if [ "$OS_FAMILY" != "Oracle Linux" ] || [ "$OS_MAJOR_VERSION" != "9" ]; then
    fail "This package requires Oracle Linux 9."
fi

if [ ! -f /etc/oracle-release ]; then
    fail "Oracle Linux was not detected."
fi

CURRENT_OS_MAJOR=$(sed -n 's/.*release \([0-9][0-9]*\).*/\1/p' /etc/oracle-release)
if [ "$CURRENT_OS_MAJOR" != "$OS_MAJOR_VERSION" ]; then
    fail "Operating system version does not match GI_Setup.conf: $(cat /etc/oracle-release)"
fi

pass "$(cat /etc/oracle-release)"

ARCHITECTURE=$(uname -m)
if [ "$ARCHITECTURE" != "x86_64" ]; then
    fail "x86_64 architecture is required; found $ARCHITECTURE."
fi

pass "Architecture is $ARCHITECTURE."

KERNEL_RELEASE=$(uname -r)
case "$KERNEL_RELEASE" in
    *el9uek*)
        MINIMUM_KERNEL="5.15.0-1.43.4.2.el9uek.x86_64"
        ;;
    *el9*)
        MINIMUM_KERNEL="5.14.0-70.22.1.0.2.el9_0.x86_64"
        ;;
    *)
        fail "Unsupported Oracle Linux 9 kernel: $KERNEL_RELEASE"
        ;;
esac

if ! version_at_least "$KERNEL_RELEASE" "$MINIMUM_KERNEL"; then
    fail "Kernel $KERNEL_RELEASE is older than required $MINIMUM_KERNEL."
fi

pass "Kernel is supported: $KERNEL_RELEASE"

if [ "$UNSUPPORTED_BASE_MODE" = "YES" ]; then
    warn "RU compatibility checks are skipped for the unsupported PERSONAL_LAB Base-only mode."
else
    if ! version_at_least "$GI_RU_VERSION" "19.19.0.0.0"; then
        fail "GI RU 19.19 or later is required for Oracle Linux 9."
    fi

    if ! version_at_least "$DB_RU_VERSION" "19.19.0.0.0"; then
        fail "Database RU 19.19 or later is required for Oracle Linux 9."
    fi

    if ! version_at_least "$GI_RU_VERSION" "19.22.0.0.0"; then
        warn "Oracle recommends GI RU 19.22 or later for Oracle Linux 9."
    fi

    if ! version_at_least "$DB_RU_VERSION" "19.22.0.0.0"; then
        warn "Oracle recommends Database RU 19.22 or later for Oracle Linux 9."
    fi

    pass "Configured RU versions meet the Oracle Linux 9 minimum."
fi

# 3. Hostname, name resolution, and time synchronization
printf '%s\n' "=== Check host configuration ==="

CURRENT_HOST_NAME=$(hostname -s)
if [ "$CURRENT_HOST_NAME" != "$HOST_NAME" ]; then
    fail "Hostname is $CURRENT_HOST_NAME; expected $HOST_NAME."
fi

pass "Hostname matches GI_Setup.conf: $HOST_NAME"

if ! getent hosts "$HOST_NAME" > /dev/null; then
    fail "Hostname cannot be resolved: $HOST_NAME"
fi

pass "Hostname resolution is available."

if command -v timedatectl > /dev/null 2>&1; then
    NTP_SYNCHRONIZED=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)
    if [ "$NTP_SYNCHRONIZED" = "yes" ]; then
        pass "Time synchronization is active."
    else
        warn "Time synchronization is not active."
    fi
else
    warn "timedatectl is not available; time synchronization was not verified."
fi

# 4. Memory, swap, and temporary space
printf '%s\n' "=== Check memory, swap, and temporary space ==="

MEMORY_MB=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
SWAP_MB=$(awk '/SwapTotal/ {print int($2 / 1024)}' /proc/meminfo)

if [ "$MEMORY_MB" -lt 4096 ]; then
    fail "At least 4096 MB RAM is required; found ${MEMORY_MB} MB."
elif [ "$MEMORY_MB" -lt 8192 ]; then
    if [ "$ENVIRONMENT" = "PERSONAL_LAB" ]; then
        warn "RAM is ${MEMORY_MB} MB; continuing with the PERSONAL_LAB exception."
    else
        fail "At least 8192 MB RAM is required; found ${MEMORY_MB} MB."
    fi
else
    pass "RAM = ${MEMORY_MB} MB"
fi

if [ "$MEMORY_MB" -le 16384 ]; then
    REQUIRED_SWAP_MB=$MEMORY_MB
else
    REQUIRED_SWAP_MB=16384
fi

if [ "$SWAP_MB" -lt "$REQUIRED_SWAP_MB" ]; then
    fail "Swap is ${SWAP_MB} MB; at least ${REQUIRED_SWAP_MB} MB is required."
fi

pass "Swap = ${SWAP_MB} MB"

TMP_FREE_MB=$(df -Pm /tmp | awk 'NR == 2 {print $4}')
if [ "$TMP_FREE_MB" -lt 1024 ]; then
    fail "/tmp has ${TMP_FREE_MB} MB free; at least 1024 MB is required."
fi

pass "/tmp free space = ${TMP_FREE_MB} MB"

# 5. Packages, kernel parameters, and limits
printf '%s\n' "=== Check packages, kernel parameters, and limits ==="

if rpm -q oracle-database-preinstall-19c > /dev/null 2>&1; then
    pass "oracle-database-preinstall-19c is installed."
else
    warn "oracle-database-preinstall-19c must be installed by 01_PreInstall.sh."
fi

if rpm -q openssh > /dev/null 2>&1; then
    pass "OpenSSH is installed."
else
    warn "OpenSSH must be installed by 01_PreInstall.sh."
fi

check_sysctl_minimum "fs.aio-max-nr" "1048576"
check_sysctl_minimum "fs.file-max" "6815744"
check_sysctl_minimum "kernel.shmmni" "4096"
check_sysctl_minimum "net.core.rmem_default" "262144"
check_sysctl_minimum "net.core.rmem_max" "4194304"
check_sysctl_minimum "net.core.wmem_default" "262144"
check_sysctl_minimum "net.core.wmem_max" "1048576"

if [ -f /etc/security/limits.d/oracle-database-preinstall-19c.conf ]; then
    pass "Oracle 19c limits configuration exists."
else
    warn "Oracle 19c limits must be configured by 01_PreInstall.sh."
fi

# 6. Groups, users, and directories
printf '%s\n' "=== Check groups, users, and directories ==="

check_group "$OINSTALL_GROUP"
check_group "$ASM_OSDBA_GROUP"
check_group "$ASM_OSASM_GROUP"
check_group "$DB_OSDBA_GROUP"
check_group "$DB_OSRACDBA_GROUP"

if [ -n "${ASM_OSOPER_GROUP:-}" ]; then
    check_group "$ASM_OSOPER_GROUP"
fi

if [ -n "${DB_OSOPER_GROUP:-}" ]; then
    check_group "$DB_OSOPER_GROUP"
fi

check_user "$GRID_OWNER" "$GRID_PRIMARY_GROUP"
check_user "$ORACLE_OWNER" "$ORACLE_PRIMARY_GROUP"

check_membership "$GRID_OWNER" "$ASM_OSDBA_GROUP"
check_membership "$GRID_OWNER" "$ASM_OSASM_GROUP"
check_membership "$GRID_OWNER" "$DB_OSDBA_GROUP"
check_membership "$GRID_OWNER" "$DB_OSRACDBA_GROUP"
check_membership "$ORACLE_OWNER" "$ASM_OSDBA_GROUP"
check_membership "$ORACLE_OWNER" "$DB_OSDBA_GROUP"
check_membership "$ORACLE_OWNER" "$DB_OSRACDBA_GROUP"

check_directory "$ORA_INVENTORY" "$GRID_OWNER" "$OINSTALL_GROUP"
check_directory "$GRID_BASE" "$GRID_OWNER" "$GRID_PRIMARY_GROUP"
check_directory "$GRID_HOME" "$GRID_OWNER" "$GRID_PRIMARY_GROUP"
check_directory "$ORACLE_BASE" "$ORACLE_OWNER" "$ORACLE_PRIMARY_GROUP"
check_directory "$DB_HOME" "$ORACLE_OWNER" "$ORACLE_PRIMARY_GROUP"

# 7. Installation media and patches
printf '%s\n' "=== Check installation media and patches ==="

if [ ! -f "$GI_SOFTWARE" ]; then
    fail "GI installation file not found: $GI_SOFTWARE"
fi

if [ ! -f "$DB_SOFTWARE" ]; then
    fail "Database installation file not found: $DB_SOFTWARE"
fi

pass "Base installation media exists."

if [ "$UNSUPPORTED_BASE_MODE" = "YES" ]; then
    warn "RU and external OPatch path checks are skipped for the unsupported PERSONAL_LAB Base-only mode."
else
    if [ ! -e "$GI_RU" ]; then
        fail "GI RU path not found: $GI_RU"
    fi

    if [ ! -e "$GI_OPATCH" ]; then
        fail "GI OPatch path not found: $GI_OPATCH"
    fi

    if [ ! -e "$DB_RU" ]; then
        fail "Database RU path not found: $DB_RU"
    fi

    if [ ! -e "$DB_OPATCH" ]; then
        fail "Database OPatch path not found: $DB_OPATCH"
    fi

    pass "Patch paths exist."
fi

# 8. ASM disk visibility
printf '%s\n' "=== Check ASM disk visibility ==="

for DISK in $ASM_DISKGROUP_DATA_DISKS $ASM_DISKGROUP_FRA_DISKS
do
    if [ ! -b "$DISK" ]; then
        fail "ASM disk is missing or is not a block device: $DISK"
    fi

    pass "ASM disk is visible: $DISK"
done

printf '\n'
if [ "$WARNING_COUNT" -gt 0 ]; then
    printf "${YELLOW}PreCheck completed with %s warning(s).${NC}\n" "$WARNING_COUNT"
else
    printf "${GREEN}PreCheck completed successfully.${NC}\n"
fi
