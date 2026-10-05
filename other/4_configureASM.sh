#!/bin/bash
set -euo pipefail

GRID_HOME="/opt/grid/product/19.3.0.0/grid"
GRID_BASE="/opt/grid/base"
ORA_INVENTORY="/opt/oraInventory"
ASM_DATA="/dev/asm-data"
ASM_FRA="/dev/asm-fra"
ASM_DISKSTRING="/dev/asm-*"
SYSASM_PASSWORD="P@ssw0rd"
RSP_FILE="/home/grid/grid_config.rsp"
HA_CONFIG_MARKER="/var/tmp/gi_ha_config.done"
HA_ROOT_MARKER="/var/tmp/gi_ha_root.done"
CONFIG_TOOLS_MARKER="/var/tmp/gi_config_tools.done"


echo "=== 1. Create GI configuration response file ==="

cat > "$RSP_FILE" <<EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0

INVENTORY_LOCATION=$ORA_INVENTORY
oracle.install.option=HA_CONFIG

ORACLE_BASE=$GRID_BASE

oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin

oracle.install.asm.SYSASMPassword=$SYSASM_PASSWORD
oracle.install.asm.monitorPassword=$SYSASM_PASSWORD

oracle.install.asm.diskGroup.name=DATA
oracle.install.asm.diskGroup.redundancy=EXTERNAL
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.disks=$ASM_DATA
oracle.install.asm.diskGroup.diskDiscoveryString=$ASM_DISKSTRING

oracle.install.asm.configureAFD=false

oracle.install.crs.rootconfig.executeRootScript=false
EOF

chown grid:oinstall "$RSP_FILE"
chmod 600 "$RSP_FILE"


echo "=== 2. Configure Oracle Restart and ASM ==="

if "$GRID_HOME/bin/crsctl" check has >/dev/null 2>&1; then
    echo "Oracle Restart is already configured."
    touch "$HA_CONFIG_MARKER"
    touch "$HA_ROOT_MARKER"

elif [ -f "$HA_CONFIG_MARKER" ]; then
    echo "Oracle Restart and ASM configuration already started."

else
    su - grid -c "
    $GRID_HOME/gridSetup.sh \
        -silent \
        -responseFile $RSP_FILE
    "

    touch "$HA_CONFIG_MARKER"
fi


echo "=== 3. Run GI root script ==="

if [ -f "$HA_ROOT_MARKER" ]; then
    echo "GI HA root script already completed."
else
    "$GRID_HOME/root.sh"
    touch "$HA_ROOT_MARKER"
fi


echo "=== 4. Complete configuration tools ==="

if [ -f "$CONFIG_TOOLS_MARKER" ]; then
    echo "GI configuration tools already completed."
else
    su - grid -c "
    $GRID_HOME/gridSetup.sh \
        -silent \
        -executeConfigTools \
        -responseFile $RSP_FILE
    "

    touch "$CONFIG_TOOLS_MARKER"
fi


echo "=== 5. Verify Oracle Restart and ASM ==="

"$GRID_HOME/bin/crsctl" check has

su - grid -c "
export ORACLE_HOME=$GRID_HOME
export ORACLE_SID=+ASM
export PATH=\$ORACLE_HOME/bin:\$PATH

srvctl status asm
asmcmd lsdg
"


echo "=== 6. Create FRA disk group ==="

if su - grid -c "
export ORACLE_HOME=$GRID_HOME
export ORACLE_SID=+ASM
export PATH=\$ORACLE_HOME/bin:\$PATH

asmcmd lsdg
" | grep -q "FRA/"; then

    echo "FRA disk group already exists."

else
    su - grid -c "
    export ORACLE_HOME=$GRID_HOME
    export ORACLE_SID=+ASM
    export PATH=\$ORACLE_HOME/bin:\$PATH

    asmca -silent \
        -createDiskGroup \
        -diskGroupName FRA \
        -disk '$ASM_FRA' \
        -redundancy EXTERNAL
    "
fi


echo "=== 7. Verify ASM disk groups ==="

su - grid -c "
export ORACLE_HOME=$GRID_HOME
export ORACLE_SID=+ASM
export PATH=\$ORACLE_HOME/bin:\$PATH

asmcmd lsdg
"

echo "=== GI configuration completed ==="