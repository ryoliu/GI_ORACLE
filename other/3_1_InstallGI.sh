#!/bin/bash
set -euo pipefail

GRID_HOME="/opt/grid/product/19.3.0.0/grid"
GRID_BASE="/opt/grid/base"
GI_SOFTWARE="/software/LINUX.X64_193000_grid_home.zip"
ORA_INVENTORY="/opt/oraInventory"
ROOT_MARKER="/var/tmp/gi_software_root.done"

echo "=== 1. Extract Grid Infrastructure software ==="

if [ ! -f "$GRID_HOME/gridSetup.sh" ]; then
    su - grid -c "unzip '$GI_SOFTWARE' -d '$GRID_HOME'"
else
    echo "Grid Infrastructure software already extracted."
fi


echo "=== 2. Install GI Software Only ==="

su - grid -c "
'$GRID_HOME/gridSetup.sh' \
    -silent \
    -waitforcompletion \
    -responseFile '$GRID_HOME/install/response/gridsetup.rsp' \
    INVENTORY_LOCATION='$ORA_INVENTORY' \
    ORACLE_BASE='$GRID_BASE' \
    oracle.install.option=CRS_SWONLY \
    oracle.install.asm.OSDBA=asmdba \
    oracle.install.asm.OSOPER=asmoper \
    oracle.install.asm.OSASM=asmadmin
"

echo "=== 3. Complete GI Software Only root scripts ==="

if [ -f "$ROOT_MARKER" ]; then
    echo "GI Software Only root scripts already completed."
else
    if [ -x "$ORA_INVENTORY/orainstRoot.sh" ]; then
        "$ORA_INVENTORY/orainstRoot.sh"
    fi

    "$GRID_HOME/root.sh"
    touch "$ROOT_MARKER"
fi

echo "=== GI Software Only installation completed ==="
