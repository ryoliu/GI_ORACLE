#!/bin/bash

set -e
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/GI_Setup.conf"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

check_required_value() {
    if [ -z "$2" ]; then
        echo -e "${RED}ERROR: $1 is not configured in GI_Setup.conf.${RESET}"
        exit 1
    fi
}

check_optional_path() {
    if [ -z "$2" ]; then
        if [ "$ENVIRONMENT" = "PERSONAL_LAB" ]; then
            echo -e "${YELLOW}WARNING: $1 is not configured. Skip.${RESET}"
            return
        fi

        echo -e "${RED}ERROR: $1 is required for $ENVIRONMENT.${RESET}"
        exit 1
    fi

    if [ ! -e "$2" ]; then
        echo -e "${RED}ERROR: $1 path not found: $2${RESET}"
        exit 1
    fi

    echo -e "${GREEN}OK: $1 path exists.${RESET}"
}

echo "=== Oracle GI / Database PreCheck ==="


# ============================================================
# 1. Check root user
# ============================================================

echo "=== Check root user ==="

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root.${RESET}"
    exit 1
fi

echo -e "${GREEN}OK: Running as root.${RESET}"


# ============================================================
# 2. Load configuration
# ============================================================

echo "=== Check configuration file ==="

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: $CONFIG_FILE${RESET}"
    exit 1
fi

source "$CONFIG_FILE"

check_required_value "ENVIRONMENT" "${ENVIRONMENT:-}"
check_required_value "OS_MAJOR_VERSION" "${OS_MAJOR_VERSION:-}"
check_required_value "HOST_NAME" "${HOST_NAME:-}"
check_required_value "GI_SOFTWARE" "${GI_SOFTWARE:-}"
check_required_value "DB_SOFTWARE" "${DB_SOFTWARE:-}"
check_required_value "ASM_DISKGROUP_DATA_DISKS" "${ASM_DISKGROUP_DATA_DISKS:-}"
check_required_value "ASM_DISKGROUP_FRA_DISKS" "${ASM_DISKGROUP_FRA_DISKS:-}"

echo -e "${GREEN}OK: Configuration file loaded.${RESET}"


# ============================================================
# 3. Check hostname setting
# ============================================================

echo "=== Check hostname setting ==="

if [ "$HOST_NAME" = "CHANGE_ME" ] || [ -z "$HOST_NAME" ]; then
    echo -e "${RED}ERROR: HOST_NAME is not configured in GI_Setup.conf.${RESET}"
    exit 1
fi

CURRENT_HOST_NAME=$(hostname -s)

if [ "$CURRENT_HOST_NAME" != "$HOST_NAME" ]; then
    echo -e "${RED}ERROR: Hostname does not match configuration.${RESET}"
    echo "Expected: $HOST_NAME"
    echo "Current : $CURRENT_HOST_NAME"
    exit 1
fi

echo -e "${GREEN}OK: HOST_NAME = $HOST_NAME${RESET}"


# ============================================================
# 4. Check operating system
# ============================================================

echo "=== Check operating system ==="

if [ ! -f /etc/oracle-release ]; then
    echo -e "${RED}ERROR: Oracle Linux was not detected.${RESET}"
    exit 1
fi

CURRENT_OS_MAJOR=$(sed -n 's/.*release \([0-9][0-9]*\).*/\1/p' /etc/oracle-release)

if [ "$CURRENT_OS_MAJOR" != "$OS_MAJOR_VERSION" ]; then
    echo -e "${RED}ERROR: Oracle Linux version does not match configuration.${RESET}"
    echo "Expected: Oracle Linux $OS_MAJOR_VERSION"
    echo "Current : $(cat /etc/oracle-release)"
    exit 1
fi

echo -e "${GREEN}OK: $(cat /etc/oracle-release)${RESET}"


# ============================================================
# 5. Check architecture
# ============================================================

echo "=== Check architecture ==="

ARCH=$(uname -m)

if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}ERROR: x86_64 architecture is required.${RESET}"
    exit 1
fi

echo -e "${GREEN}OK: Architecture is $ARCH.${RESET}"


# ============================================================
# 6. Check memory and swap
# ============================================================

echo "=== Check memory and swap ==="

MEM_MB=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
SWAP_MB=$(awk '/SwapTotal/ {print int($2 / 1024)}' /proc/meminfo)

if [ "$MEM_MB" -lt 4096 ]; then
    echo -e "${RED}ERROR: At least 4 GB RAM is required.${RESET}"
    echo "Current RAM: ${MEM_MB} MB"
    exit 1
fi

if [ "$MEM_MB" -le 16384 ]; then
    REQUIRED_SWAP_MB=$MEM_MB
else
    REQUIRED_SWAP_MB=16384
fi

if [ "$SWAP_MB" -lt "$REQUIRED_SWAP_MB" ]; then
    echo -e "${RED}ERROR: Swap space is insufficient.${RESET}"
    echo "RAM           : ${MEM_MB} MB"
    echo "Swap          : ${SWAP_MB} MB"
    echo "Required Swap : ${REQUIRED_SWAP_MB} MB"
    exit 1
fi

echo -e "${GREEN}OK: RAM  = ${MEM_MB} MB${RESET}"
echo -e "${GREEN}OK: Swap = ${SWAP_MB} MB${RESET}"


# ============================================================
# 7. Check /tmp space
# ============================================================

echo "=== Check /tmp space ==="

TMP_FREE_MB=$(df -Pm /tmp | awk 'NR==2 {print $4}')

if [ "$TMP_FREE_MB" -lt 1024 ]; then
    echo -e "${RED}ERROR: /tmp requires at least 1 GB free space.${RESET}"
    echo "Current free space: ${TMP_FREE_MB} MB"
    exit 1
fi

echo -e "${GREEN}OK: /tmp free space = ${TMP_FREE_MB} MB${RESET}"


# ============================================================
# 8. Check installation media
# ============================================================

echo "=== Check installation media ==="

if [ ! -f "$GI_SOFTWARE" ]; then
    echo -e "${RED}ERROR: Grid Infrastructure installation file not found:${RESET}"
    echo "$GI_SOFTWARE"
    exit 1
fi

if [ ! -f "$DB_SOFTWARE" ]; then
    echo -e "${RED}ERROR: Database installation file not found:${RESET}"
    echo "$DB_SOFTWARE"
    exit 1
fi

echo -e "${GREEN}OK: Grid Infrastructure installation file exists.${RESET}"
echo -e "${GREEN}OK: Database installation file exists.${RESET}"


# ============================================================
# 9. Check optional patches
# ============================================================

echo "=== Check optional patches ==="

check_optional_path "GI RU" "${GI_RU:-}"
check_optional_path "GI OPatch" "${GI_OPATCH:-}"
check_optional_path "Database RU" "${DB_RU:-}"
check_optional_path "Database OPatch" "${DB_OPATCH:-}"


# ============================================================
# 10. Check ASM disks
# ============================================================

echo "=== Check ASM disks ==="

for DISK in $ASM_DISKGROUP_DATA_DISKS $ASM_DISKGROUP_FRA_DISKS
do
    if [ ! -b "$DISK" ]; then
        echo -e "${RED}ERROR: ASM disk not found or is not a block device: $DISK${RESET}"
        exit 1
    fi

    echo -e "${GREEN}OK: $DISK${RESET}"
done


echo
echo -e "${GREEN}============================================${RESET}"
echo -e "${GREEN}PreCheck completed successfully.${RESET}"
echo -e "${GREEN}============================================${RESET}"
