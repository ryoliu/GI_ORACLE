#!/bin/bash

set -e
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/GI_Setup.conf"
STATE_FILE="$SCRIPT_DIR/.02_InstallGI.completed"

echo "=== Oracle Grid Infrastructure Installation ==="

# ============================================================
# 1. Check execution account and load configuration
# ============================================================

echo "=== Check execution account and configuration ==="

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

for VARIABLE_NAME in \
    GRID_OWNER \
    GRID_BASE \
    GRID_HOME \
    ORA_INVENTORY \
    GI_BASE_VERSION \
    GI_SOFTWARE \
    GI_RU_VERSION \
    GI_RU \
    GI_OPATCH_VERSION \
    GI_OPATCH \
    ASM_OSDBA_GROUP \
    ASM_OSASM_GROUP \
    ASM_DISCOVERY_STRING \
    ASM_DISKGROUP_DATA \
    ASM_DISKGROUP_DATA_REDUNDANCY \
    ASM_DISKGROUP_DATA_AU_SIZE \
    ASM_DISKGROUP_DATA_DISKS
do
    VARIABLE_VALUE="${!VARIABLE_NAME:-}"
    if [ -z "$VARIABLE_VALUE" ] || [ "$VARIABLE_VALUE" = "CHANGE_ME" ]; then
        echo "ERROR: $VARIABLE_NAME is not configured in GI_Setup.conf."
        exit 1
    fi
done

if [ "$(id -un)" != "$GRID_OWNER" ]; then
    echo "ERROR: Current user does not match GRID_OWNER: $GRID_OWNER"
    exit 1
fi

# ============================================================
# 2. Check previous installation state
# ============================================================

echo "=== Check previous installation state ==="

EXPECTED_STATE="$GI_BASE_VERSION|$GI_RU_VERSION|$GI_OPATCH_VERSION|$GRID_HOME"

if [ -f "$STATE_FILE" ]; then
    CURRENT_STATE=$(cat "$STATE_FILE")

    if [ "$CURRENT_STATE" != "$EXPECTED_STATE" ]; then
        echo "ERROR: Previous installation state conflicts with GI_Setup.conf."
        exit 1
    fi

    echo "PASS: Grid Infrastructure installer already completed."
    echo "Run the following commands as root if they are still pending:"
    if [ -x "$ORA_INVENTORY/orainstRoot.sh" ]; then
        echo "  $ORA_INVENTORY/orainstRoot.sh"
    fi
    echo "  $GRID_HOME/root.sh"
    echo "After the root scripts complete, run 03_ConfigGI.sh as $GRID_OWNER."
    exit 0
fi

# ============================================================
# 3. Check installation media
# ============================================================

echo "=== Check installation media ==="

if ! command -v unzip > /dev/null 2>&1; then
    echo "ERROR: unzip command is not available."
    exit 1
fi

if [ ! -f "$GI_SOFTWARE" ]; then
    echo "ERROR: GI software image not found: $GI_SOFTWARE"
    exit 1
fi

if [ ! -d "$GI_RU" ]; then
    echo "ERROR: GI_RU must point to an extracted RU directory: $GI_RU"
    exit 1
fi

if [ ! -f "$GI_OPATCH" ]; then
    echo "ERROR: OPatch archive not found: $GI_OPATCH"
    exit 1
fi

echo "PASS: Installation media is available."

# ============================================================
# 4. Prepare Grid Home
# ============================================================

echo "=== Prepare Grid Home ==="

if [ ! -d "$GRID_HOME" ]; then
    echo "ERROR: GRID_HOME directory not found: $GRID_HOME"
    exit 1
fi

if [ -x "$GRID_HOME/gridSetup.sh" ]; then
    echo "PASS: GI Gold Image is already extracted."
else
    if find "$GRID_HOME" -mindepth 1 -print -quit | grep -q .; then
        echo "ERROR: GRID_HOME is not empty and gridSetup.sh was not found: $GRID_HOME"
        exit 1
    fi

    unzip -q "$GI_SOFTWARE" -d "$GRID_HOME"

    if [ ! -x "$GRID_HOME/gridSetup.sh" ]; then
        echo "ERROR: GI Gold Image extraction failed."
        exit 1
    fi

    echo "PASS: GI Gold Image extracted."
fi

# ============================================================
# 5. Update OPatch
# ============================================================

echo "=== Update OPatch ==="

CURRENT_OPATCH_VERSION=$(
    "$GRID_HOME/OPatch/opatch" version 2>/dev/null |
        awk -F': ' '/OPatch Version/ {print $2}'
)

if [ "$CURRENT_OPATCH_VERSION" = "$GI_OPATCH_VERSION" ]; then
    echo "PASS: Required OPatch version is already installed."
else
    if [ -e "$GRID_HOME/OPatch.base" ]; then
        echo "ERROR: OPatch backup already exists and the active version is unexpected."
        exit 1
    fi

    mv "$GRID_HOME/OPatch" "$GRID_HOME/OPatch.base"
    unzip -q "$GI_OPATCH" -d "$GRID_HOME"

    CURRENT_OPATCH_VERSION=$(
        "$GRID_HOME/OPatch/opatch" version 2>/dev/null |
            awk -F': ' '/OPatch Version/ {print $2}'
    )

    if [ "$CURRENT_OPATCH_VERSION" != "$GI_OPATCH_VERSION" ]; then
        echo "ERROR: OPatch version does not match GI_OPATCH_VERSION."
        exit 1
    fi

    echo "PASS: OPatch updated to $CURRENT_OPATCH_VERSION."
fi

# ============================================================
# 6. Create a temporary response file
# ============================================================

echo "=== Create temporary response file ==="

read -r -s -p "Enter SYSASM password: " ASM_SYS_PASSWORD
echo
read -r -s -p "Enter ASMSNMP password: " ASM_MONITOR_PASSWORD
echo

if [ -z "$ASM_SYS_PASSWORD" ] || [ -z "$ASM_MONITOR_PASSWORD" ]; then
    echo "ERROR: ASM passwords cannot be empty."
    exit 1
fi

RESPONSE_FILE=$(mktemp "$SCRIPT_DIR/grid_install.XXXXXX.rsp")
chmod 600 "$RESPONSE_FILE"
trap 'rm -f "$RESPONSE_FILE"' EXIT

cat > "$RESPONSE_FILE" <<EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0
INVENTORY_LOCATION=$ORA_INVENTORY
oracle.install.option=HA_CONFIG
ORACLE_BASE=$GRID_BASE
oracle.install.asm.OSDBA=$ASM_OSDBA_GROUP
oracle.install.asm.OSOPER=${ASM_OSOPER_GROUP:-}
oracle.install.asm.OSASM=$ASM_OSASM_GROUP
oracle.install.asm.SYSASMPassword=$ASM_SYS_PASSWORD
oracle.install.asm.diskGroup.name=$ASM_DISKGROUP_DATA
oracle.install.asm.diskGroup.redundancy=$ASM_DISKGROUP_DATA_REDUNDANCY
oracle.install.asm.diskGroup.AUSize=$ASM_DISKGROUP_DATA_AU_SIZE
oracle.install.asm.diskGroup.disks=$ASM_DISKGROUP_DATA_DISKS
oracle.install.asm.diskGroup.diskDiscoveryString=$ASM_DISCOVERY_STRING
oracle.install.asm.monitorPassword=$ASM_MONITOR_PASSWORD
oracle.install.config.managementOption=NONE
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=ROOT
EOF

unset ASM_SYS_PASSWORD
unset ASM_MONITOR_PASSWORD

echo "PASS: Temporary response file created."

# ============================================================
# 7. Install Oracle Grid Infrastructure
# ============================================================

echo "=== Install Oracle Grid Infrastructure ==="

if [ -n "${GI_ONEOFFS:-}" ]; then
    "$GRID_HOME/gridSetup.sh" \
        -silent \
        -waitforcompletion \
        -responseFile "$RESPONSE_FILE" \
        -applyRU "$GI_RU" \
        -applyOneOffs "$GI_ONEOFFS"
else
    "$GRID_HOME/gridSetup.sh" \
        -silent \
        -waitforcompletion \
        -responseFile "$RESPONSE_FILE" \
        -applyRU "$GI_RU"
fi

printf '%s\n' "$EXPECTED_STATE" > "$STATE_FILE"
chmod 600 "$STATE_FILE"

echo "PASS: Grid Infrastructure installer completed."

# ============================================================
# 8. Hand off root scripts
# ============================================================

echo "=== Root script handoff ==="
echo "Run the following commands as root:"
if [ -x "$ORA_INVENTORY/orainstRoot.sh" ]; then
    echo "  $ORA_INVENTORY/orainstRoot.sh"
fi
echo "  $GRID_HOME/root.sh"
echo "Do not run the root scripts from this script."
echo "After the root scripts complete, run 03_ConfigGI.sh as $GRID_OWNER."
