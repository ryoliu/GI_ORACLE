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

if [ -z "${ALLOW_UNSUPPORTED_19_3_BASE:-}" ]; then
    echo "ERROR: ALLOW_UNSUPPORTED_19_3_BASE is not configured in GI_Setup.conf."
    exit 1
fi

UNSUPPORTED_BASE_MODE="NO"

if [ "$ALLOW_UNSUPPORTED_19_3_BASE" = "YES" ]; then
    if [ "$ENVIRONMENT" != "PERSONAL_LAB" ]; then
        echo "ERROR: Unsupported Base-only mode is allowed only for PERSONAL_LAB."
        exit 1
    fi

    UNSUPPORTED_BASE_MODE="YES"
    echo "WARNING: Oracle 19.3 Base without RU is not supported on Oracle Linux 9."
elif [ "$ALLOW_UNSUPPORTED_19_3_BASE" != "NO" ]; then
    echo "ERROR: ALLOW_UNSUPPORTED_19_3_BASE must be YES or NO."
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

if [ -z "${GI_BASE_VERSION:-}" ]; then
    echo "ERROR: GI_BASE_VERSION is not configured in GI_Setup.conf."
    exit 1
fi

if [ "$UNSUPPORTED_BASE_MODE" = "NO" ]; then
    if [ -z "${GI_RU_VERSION:-}" ] || [ "$GI_RU_VERSION" = "CHANGE_ME" ]; then
        echo "ERROR: GI_RU_VERSION is not configured in GI_Setup.conf."
        exit 1
    fi

    if [ -z "${GI_RU:-}" ] || [ "$GI_RU" = "CHANGE_ME" ]; then
        echo "ERROR: GI_RU is not configured in GI_Setup.conf."
        exit 1
    fi

    if [ -z "${GI_OPATCH_VERSION:-}" ] || [ "$GI_OPATCH_VERSION" = "CHANGE_ME" ]; then
        echo "ERROR: GI_OPATCH_VERSION is not configured in GI_Setup.conf."
        exit 1
    fi

    if [ -z "${GI_OPATCH:-}" ] || [ "$GI_OPATCH" = "CHANGE_ME" ]; then
        echo "ERROR: GI_OPATCH is not configured in GI_Setup.conf."
        exit 1
    fi
fi

if [ -z "${DB_BASE_VERSION:-}" ]; then
    echo "ERROR: DB_BASE_VERSION is not configured in GI_Setup.conf."
    exit 1
fi

if [ "$UNSUPPORTED_BASE_MODE" = "NO" ]; then
    if [ -z "${DB_RU_VERSION:-}" ] || [ "$DB_RU_VERSION" = "CHANGE_ME" ]; then
        echo "ERROR: DB_RU_VERSION is not configured in GI_Setup.conf."
        exit 1
    fi

    if [ -z "${DB_RU:-}" ] || [ "$DB_RU" = "CHANGE_ME" ]; then
        echo "ERROR: DB_RU is not configured in GI_Setup.conf."
        exit 1
    fi

    if [ -z "${DB_OPATCH_VERSION:-}" ] || [ "$DB_OPATCH_VERSION" = "CHANGE_ME" ]; then
        echo "ERROR: DB_OPATCH_VERSION is not configured in GI_Setup.conf."
        exit 1
    fi

    if [ -z "${DB_OPATCH:-}" ] || [ "$DB_OPATCH" = "CHANGE_ME" ]; then
        echo "ERROR: DB_OPATCH is not configured in GI_Setup.conf."
        exit 1
    fi
fi

if [ -z "${ASM_OSDBA_GROUP:-}" ]; then
    echo "ERROR: ASM_OSDBA_GROUP is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${ASM_OSASM_GROUP:-}" ]; then
    echo "ERROR: ASM_OSASM_GROUP is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${DB_OSDBA_GROUP:-}" ]; then
    echo "ERROR: DB_OSDBA_GROUP is not configured in GI_Setup.conf."
    exit 1
fi

if [ -z "${DB_OSRACDBA_GROUP:-}" ]; then
    echo "ERROR: DB_OSRACDBA_GROUP is not configured in GI_Setup.conf."
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
elif [ "$MEM_MB" -lt 8192 ]; then
    if [ "$ENVIRONMENT" = "PERSONAL_LAB" ]; then
        echo "WARNING: RAM is below the official 8 GB requirement."
        echo "WARNING: Continue with the personal LAB exception."
    else
        echo "ERROR: At least 8 GB RAM is required."
        echo "Current RAM: ${MEM_MB} MB"
        exit 1
    fi
else
    echo "OK: RAM = ${MEM_MB} MB"
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
# 9. Check patches
# ============================================================

echo "=== Check patches ==="

if [ "$UNSUPPORTED_BASE_MODE" = "YES" ]; then
    echo "WARNING: RU and external OPatch checks are skipped for the unsupported PERSONAL_LAB Base-only mode."
else
    if [ ! -e "$GI_RU" ]; then
        echo "ERROR: GI RU path not found: $GI_RU"
        exit 1
    fi

    if [ ! -e "$GI_OPATCH" ]; then
        echo "ERROR: GI OPatch path not found: $GI_OPATCH"
        exit 1
    fi

    if [ ! -e "$DB_RU" ]; then
        echo "ERROR: Database RU path not found: $DB_RU"
        exit 1
    fi

    if [ ! -e "$DB_OPATCH" ]; then
        echo "ERROR: Database OPatch path not found: $DB_OPATCH"
        exit 1
    fi

    echo "OK: Patch paths exist."
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
