#!/bin/bash

set -e
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/GI_Setup.conf"
GRID_LIMITS_FILE="/etc/security/limits.d/99-oracle-grid.conf"

echo "=== Oracle GI / Database PreInstall ==="

# ============================================================
# 1. Check execution account and load configuration
# ============================================================

echo "=== Check execution account and configuration ==="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

for VARIABLE_NAME in \
    OS_MAJOR_VERSION \
    OINSTALL_GROUP \
    GRID_OWNER \
    GRID_PRIMARY_GROUP \
    ORACLE_OWNER \
    ORACLE_PRIMARY_GROUP \
    ASM_OSDBA_GROUP \
    ASM_OSASM_GROUP \
    DB_OSDBA_GROUP \
    DB_OSRACDBA_GROUP \
    ORA_INVENTORY \
    GRID_BASE \
    GRID_HOME \
    ORACLE_BASE \
    DB_HOME \
    ASM_DISKGROUP_DATA_DISKS \
    ASM_DISKGROUP_FRA_DISKS
do
    VARIABLE_VALUE="${!VARIABLE_NAME:-}"
    if [ -z "$VARIABLE_VALUE" ] || [ "$VARIABLE_VALUE" = "CHANGE_ME" ]; then
        echo "ERROR: $VARIABLE_NAME is not configured in GI_Setup.conf."
        exit 1
    fi
done

if [ "$OS_MAJOR_VERSION" != "9" ]; then
    echo "ERROR: This template is designed for Oracle Linux 9."
    exit 1
fi

if [ "$GRID_PRIMARY_GROUP" != "$OINSTALL_GROUP" ]; then
    echo "ERROR: GRID_PRIMARY_GROUP must match OINSTALL_GROUP."
    exit 1
fi

if [ "$ORACLE_PRIMARY_GROUP" != "$OINSTALL_GROUP" ]; then
    echo "ERROR: ORACLE_PRIMARY_GROUP must match OINSTALL_GROUP."
    exit 1
fi

# ============================================================
# 2. Install operating system prerequisites
# ============================================================

echo "=== Install operating system prerequisites ==="

if rpm -q oracle-database-preinstall-19c > /dev/null 2>&1; then
    echo "PASS: oracle-database-preinstall-19c is already installed."
else
    dnf install -y oracle-database-preinstall-19c

    if ! rpm -q oracle-database-preinstall-19c > /dev/null 2>&1; then
        echo "ERROR: oracle-database-preinstall-19c installation failed."
        exit 1
    fi

    echo "PASS: oracle-database-preinstall-19c installed."
fi

# ============================================================
# 3. Create operating system groups
# ============================================================

echo "=== Configure operating system groups ==="

REQUIRED_GROUPS="$OINSTALL_GROUP $ASM_OSDBA_GROUP $ASM_OSASM_GROUP $DB_OSDBA_GROUP $DB_OSRACDBA_GROUP"

if [ -n "${ASM_OSOPER_GROUP:-}" ]; then
    REQUIRED_GROUPS="$REQUIRED_GROUPS $ASM_OSOPER_GROUP"
fi

if [ -n "${DB_OSOPER_GROUP:-}" ]; then
    REQUIRED_GROUPS="$REQUIRED_GROUPS $DB_OSOPER_GROUP"
fi

for GROUP_NAME in $REQUIRED_GROUPS
do
    if getent group "$GROUP_NAME" > /dev/null; then
        echo "PASS: Group already exists: $GROUP_NAME"
    else
        groupadd "$GROUP_NAME"
        getent group "$GROUP_NAME" > /dev/null
        echo "PASS: Group created: $GROUP_NAME"
    fi
done

# ============================================================
# 4. Create Grid and Oracle owners
# ============================================================

echo "=== Configure Grid owner ==="

GRID_SECONDARY_GROUPS="$ASM_OSASM_GROUP,$ASM_OSDBA_GROUP,$DB_OSDBA_GROUP,$DB_OSRACDBA_GROUP"

if [ -n "${ASM_OSOPER_GROUP:-}" ]; then
    GRID_SECONDARY_GROUPS="$GRID_SECONDARY_GROUPS,$ASM_OSOPER_GROUP"
fi

if id "$GRID_OWNER" > /dev/null 2>&1; then
    if [ "$(id -gn "$GRID_OWNER")" != "$GRID_PRIMARY_GROUP" ]; then
        echo "ERROR: $GRID_OWNER has an unexpected primary group."
        exit 1
    fi
else
    useradd -m -g "$GRID_PRIMARY_GROUP" -G "$GRID_SECONDARY_GROUPS" "$GRID_OWNER"
fi

for GROUP_NAME in $(printf '%s' "$GRID_SECONDARY_GROUPS" | tr ',' ' ')
do
    if id -nG "$GRID_OWNER" | tr ' ' '\n' | grep -qx "$GROUP_NAME"; then
        echo "PASS: $GRID_OWNER already belongs to $GROUP_NAME."
    else
        usermod -a -G "$GROUP_NAME" "$GRID_OWNER"
        echo "PASS: $GRID_OWNER added to $GROUP_NAME."
    fi
done

echo "=== Configure Oracle owner ==="

ORACLE_SECONDARY_GROUPS="$DB_OSDBA_GROUP,$DB_OSRACDBA_GROUP,$ASM_OSDBA_GROUP"

if [ -n "${DB_OSOPER_GROUP:-}" ]; then
    ORACLE_SECONDARY_GROUPS="$ORACLE_SECONDARY_GROUPS,$DB_OSOPER_GROUP"
fi

if id "$ORACLE_OWNER" > /dev/null 2>&1; then
    if [ "$(id -gn "$ORACLE_OWNER")" != "$ORACLE_PRIMARY_GROUP" ]; then
        echo "ERROR: $ORACLE_OWNER has an unexpected primary group."
        exit 1
    fi
else
    useradd -m -g "$ORACLE_PRIMARY_GROUP" -G "$ORACLE_SECONDARY_GROUPS" "$ORACLE_OWNER"
fi

for GROUP_NAME in $(printf '%s' "$ORACLE_SECONDARY_GROUPS" | tr ',' ' ')
do
    if id -nG "$ORACLE_OWNER" | tr ' ' '\n' | grep -qx "$GROUP_NAME"; then
        echo "PASS: $ORACLE_OWNER already belongs to $GROUP_NAME."
    else
        usermod -a -G "$GROUP_NAME" "$ORACLE_OWNER"
        echo "PASS: $ORACLE_OWNER added to $GROUP_NAME."
    fi
done

# ============================================================
# 5. Create Oracle directories
# ============================================================

echo "=== Configure Grid directories ==="

for DIRECTORY_PATH in "$ORA_INVENTORY" "$GRID_BASE" "$GRID_HOME"
do
    if [ -e "$DIRECTORY_PATH" ] && [ ! -d "$DIRECTORY_PATH" ]; then
        echo "ERROR: Path exists but is not a directory: $DIRECTORY_PATH"
        exit 1
    fi

    if [ -d "$DIRECTORY_PATH" ]; then
        if [ "$(stat -c '%U:%G' "$DIRECTORY_PATH")" != "$GRID_OWNER:$OINSTALL_GROUP" ]; then
            echo "ERROR: Directory ownership conflicts with the configuration: $DIRECTORY_PATH"
            exit 1
        fi
        echo "PASS: Directory already exists: $DIRECTORY_PATH"
    else
        install -d -m 0775 -o "$GRID_OWNER" -g "$OINSTALL_GROUP" "$DIRECTORY_PATH"
        echo "PASS: Directory created: $DIRECTORY_PATH"
    fi
done

echo "=== Configure Database directories ==="

for DIRECTORY_PATH in "$ORACLE_BASE" "$DB_HOME"
do
    if [ -e "$DIRECTORY_PATH" ] && [ ! -d "$DIRECTORY_PATH" ]; then
        echo "ERROR: Path exists but is not a directory: $DIRECTORY_PATH"
        exit 1
    fi

    if [ -d "$DIRECTORY_PATH" ]; then
        if [ "$(stat -c '%U:%G' "$DIRECTORY_PATH")" != "$ORACLE_OWNER:$OINSTALL_GROUP" ]; then
            echo "ERROR: Directory ownership conflicts with the configuration: $DIRECTORY_PATH"
            exit 1
        fi
        echo "PASS: Directory already exists: $DIRECTORY_PATH"
    else
        install -d -m 0775 -o "$ORACLE_OWNER" -g "$OINSTALL_GROUP" "$DIRECTORY_PATH"
        echo "PASS: Directory created: $DIRECTORY_PATH"
    fi
done

# ============================================================
# 6. Verify kernel parameters configured by the preinstall RPM
# ============================================================

echo "=== Verify kernel parameters ==="

if [ "$(sysctl -n fs.aio-max-nr)" -lt 1048576 ]; then
    echo "ERROR: fs.aio-max-nr is lower than 1048576."
    exit 1
fi

if [ "$(sysctl -n fs.file-max)" -lt 6815744 ]; then
    echo "ERROR: fs.file-max is lower than 6815744."
    exit 1
fi

echo "PASS: Required kernel parameters are active."

# ============================================================
# 7. Configure Grid owner resource limits
# ============================================================

echo "=== Configure Grid owner resource limits ==="

EXPECTED_LIMITS=$(mktemp)
trap 'rm -f "$EXPECTED_LIMITS"' EXIT

cat > "$EXPECTED_LIMITS" <<EOF
$GRID_OWNER soft nofile 1024
$GRID_OWNER hard nofile 65536
$GRID_OWNER soft nproc 2047
$GRID_OWNER hard nproc 16384
$GRID_OWNER soft stack 10240
$GRID_OWNER hard stack 32768
EOF

if [ -f "$GRID_LIMITS_FILE" ]; then
    if ! cmp -s "$EXPECTED_LIMITS" "$GRID_LIMITS_FILE"; then
        echo "ERROR: Existing limits file conflicts with the expected configuration: $GRID_LIMITS_FILE"
        exit 1
    fi
    echo "PASS: Grid owner resource limits are already configured."
else
    install -m 0644 "$EXPECTED_LIMITS" "$GRID_LIMITS_FILE"
    echo "PASS: Grid owner resource limits configured."
fi

# ============================================================
# 8. Verify ASM device permissions
# ============================================================

echo "=== Verify ASM device permissions ==="
echo "WARNING: This template does not partition disks, clear headers, or create ASM labels."

# The final generated script must configure ASMLIB or UDEV from
# explicitly confirmed inputs before verifying the device permissions.

for DISK_PATH in $ASM_DISKGROUP_DATA_DISKS $ASM_DISKGROUP_FRA_DISKS
do
    if [ ! -b "$DISK_PATH" ]; then
        echo "ERROR: ASM disk is missing or is not a block device: $DISK_PATH"
        exit 1
    fi

    if [ "$(stat -Lc '%U:%G' "$DISK_PATH")" != "$GRID_OWNER:$ASM_OSASM_GROUP" ]; then
        echo "ERROR: ASM disk ownership conflicts with the configuration: $DISK_PATH"
        exit 1
    fi

    echo "PASS: ASM disk permission is correct: $DISK_PATH"
done

echo "PASS: PreInstall completed."
