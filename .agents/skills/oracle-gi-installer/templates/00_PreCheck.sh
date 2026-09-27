#!/bin/bash

set -e
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/GI_Setup.conf"

echo "=== Oracle GI / Database PreCheck ==="


# ============================================================
# 1. Check root user
# ============================================================

echo "=== Check root user ==="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

echo "OK: Running as root."


# ============================================================
# 2. Load configuration
# ============================================================

echo "=== Check configuration file ==="

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "${ENVIRONMENT:-}" ]; then
    echo "ERROR: ENVIRONMENT is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${OS_MAJOR_VERSION:-}" ]; then
    echo "ERROR: OS_MAJOR_VERSION is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${HOST_NAME:-}" ]; then
    echo "ERROR: HOST_NAME is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${GI_SOFTWARE:-}" ]; then
    echo "ERROR: GI_SOFTWARE is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${DB_SOFTWARE:-}" ]; then
    echo "ERROR: DB_SOFTWARE is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${ASM_DISKGROUP_DATA_DISKS:-}" ]; then
    echo "ERROR: ASM_DISKGROUP_DATA_DISKS is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${ASM_DISKGROUP_FRA_DISKS:-}" ]; then
    echo "ERROR: ASM_DISKGROUP_FRA_DISKS is not configured in GI_Setup.conf."
    exit 1
fi

echo "OK: Configuration file loaded."


# ============================================================
# 3. Check hostname setting
# ============================================================

echo "=== Check hostname setting ==="

if [ "$HOST_NAME" = "CHANGE_ME" ]; then
    echo "ERROR: HOST_NAME is not configured in GI_Setup.conf."
    exit 1
fi

CURRENT_HOST_NAME=$(hostname -s)

if [ "$CURRENT_HOST_NAME" != "$HOST_NAME" ]; then
    echo "ERROR: Hostname does not match configuration."
    echo "Expected: $HOST_NAME"
    echo "Current : $CURRENT_HOST_NAME"
    exit 1
fi

echo "OK: HOST_NAME = $HOST_NAME"


# ============================================================
# 4. Check operating system
# ============================================================

echo "=== Check operating system ==="

if [ ! -f /etc/oracle-release ]; then
    echo "ERROR: Oracle Linux was not detected."
    exit 1
fi

CURRENT_OS_MAJOR=$(sed -n 's/.*release \([0-9][0-9]*\).*/\1/p' /etc/oracle-release)

if [ "$CURRENT_OS_MAJOR" != "$OS_MAJOR_VERSION" ]; then
    echo "ERROR: Oracle Linux version does not match configuration."
    echo "Expected: Oracle Linux $OS_MAJOR_VERSION"
    echo "Current : $(cat /etc/oracle-release)"
    exit 1
fi

echo "OK: $(cat /etc/oracle-release)"


# ============================================================
# 5. Check architecture
# ============================================================

echo "=== Check architecture ==="

ARCH=$(uname -m)

if [ "$ARCH" != "x86_64" ]; then
    echo "ERROR: x86_64 architecture is required."
    exit 1
fi

echo "OK: Architecture is $ARCH."


# ============================================================
# 6. Check memory and swap
# ============================================================

echo "=== Check memory and swap ==="

MEM_MB=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
SWAP_MB=$(awk '/SwapTotal/ {print int($2 / 1024)}' /proc/meminfo)

if [ "$MEM_MB" -lt 4096 ]; then
    echo "ERROR: At least 4 GB RAM is required."
    echo "Current RAM: ${MEM_MB} MB"
    exit 1
fi

if [ "$MEM_MB" -le 16384 ]; then
    REQUIRED_SWAP_MB=$MEM_MB
else
    REQUIRED_SWAP_MB=16384
fi

if [ "$SWAP_MB" -lt "$REQUIRED_SWAP_MB" ]; then
    echo "ERROR: Swap space is insufficient."
    echo "RAM           : ${MEM_MB} MB"
    echo "Swap          : ${SWAP_MB} MB"
    echo "Required Swap : ${REQUIRED_SWAP_MB} MB"
    exit 1
fi

echo "OK: RAM  = ${MEM_MB} MB"
echo "OK: Swap = ${SWAP_MB} MB"


# ============================================================
# 7. Check /tmp space
# ============================================================

echo "=== Check /tmp space ==="

TMP_FREE_MB=$(df -Pm /tmp | awk 'NR==2 {print $4}')

if [ "$TMP_FREE_MB" -lt 1024 ]; then
    echo "ERROR: /tmp requires at least 1 GB free space."
    echo "Current free space: ${TMP_FREE_MB} MB"
    exit 1
fi

echo "OK: /tmp free space = ${TMP_FREE_MB} MB"


# ============================================================
# 8. Check installation media
# ============================================================

echo "=== Check installation media ==="

if [ ! -f "$GI_SOFTWARE" ]; then
    echo "ERROR: Grid Infrastructure installation file not found:"
    echo "$GI_SOFTWARE"
    exit 1
fi

if [ ! -f "$DB_SOFTWARE" ]; then
    echo "ERROR: Database installation file not found:"
    echo "$DB_SOFTWARE"
    exit 1
fi

echo "OK: Grid Infrastructure installation file exists."
echo "OK: Database installation file exists."


# ============================================================
# 9. Check optional patches
# ============================================================

echo "=== Check optional patches ==="

if [ -z "${GI_RU:-}" ]; then
    if [ "$ENVIRONMENT" = "PERSONAL_LAB" ]; then
        echo "WARNING: GI RU is not configured. Skip."
    else
        echo "ERROR: GI RU is required for $ENVIRONMENT."
        exit 1
    fi
elif [ ! -e "$GI_RU" ]; then
    echo "ERROR: GI RU path not found: $GI_RU"
    exit 1
else
    echo "OK: GI RU path exists."
fi

if [ -z "${GI_OPATCH:-}" ]; then
    if [ "$ENVIRONMENT" = "PERSONAL_LAB" ]; then
        echo "WARNING: GI OPatch is not configured. Skip."
    else
        echo "ERROR: GI OPatch is required for $ENVIRONMENT."
        exit 1
    fi
elif [ ! -e "$GI_OPATCH" ]; then
    echo "ERROR: GI OPatch path not found: $GI_OPATCH"
    exit 1
else
    echo "OK: GI OPatch path exists."
fi

if [ -z "${DB_RU:-}" ]; then
    if [ "$ENVIRONMENT" = "PERSONAL_LAB" ]; then
        echo "WARNING: Database RU is not configured. Skip."
    else
        echo "ERROR: Database RU is required for $ENVIRONMENT."
        exit 1
    fi
elif [ ! -e "$DB_RU" ]; then
    echo "ERROR: Database RU path not found: $DB_RU"
    exit 1
else
    echo "OK: Database RU path exists."
fi

if [ -z "${DB_OPATCH:-}" ]; then
    if [ "$ENVIRONMENT" = "PERSONAL_LAB" ]; then
        echo "WARNING: Database OPatch is not configured. Skip."
    else
        echo "ERROR: Database OPatch is required for $ENVIRONMENT."
        exit 1
    fi
elif [ ! -e "$DB_OPATCH" ]; then
    echo "ERROR: Database OPatch path not found: $DB_OPATCH"
    exit 1
else
    echo "OK: Database OPatch path exists."
fi


# ============================================================
# 10. Check ASM disks
# ============================================================

echo "=== Check ASM disks ==="

for DISK in $ASM_DISKGROUP_DATA_DISKS $ASM_DISKGROUP_FRA_DISKS
do
    if [ ! -b "$DISK" ]; then
        echo "ERROR: ASM disk not found or is not a block device: $DISK"
        exit 1
    fi

    echo "OK: $DISK"
done


echo
echo "============================================"
echo "PreCheck completed successfully."
echo "============================================"
