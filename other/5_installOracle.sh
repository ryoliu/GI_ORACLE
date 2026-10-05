#!/bin/bash
set -euo pipefail

ORACLE_BASE="/opt/oracle"
ORACLE_HOME="/opt/oracle/product/19.3.0.0/db_1"
ORA_INVENTORY="/opt/oraInventory"
DB_SOFTWARE="/software/LINUX.X64_193000_db_home.zip"

INVENTORY_XML="$ORA_INVENTORY/ContentsXML/inventory.xml"
ROOT_MARKER="$ORACLE_HOME/.root_done"

echo "=== 1. Extract Database software ==="

if [ -f "$ORACLE_HOME/runInstaller" ]; then
    echo "Database software already extracted."
else
    su - oracle -c "
    unzip '$DB_SOFTWARE' -d '$ORACLE_HOME'
    "
fi


echo "=== 2. Install Database Software Only ==="

if [ -f "$INVENTORY_XML" ] && \
   grep -Fq "LOC=\"$ORACLE_HOME\"" "$INVENTORY_XML"; then

    echo "Oracle Database software is already installed."

else
    su - oracle -c "
    export ORACLE_BASE='$ORACLE_BASE'
    export ORACLE_HOME='$ORACLE_HOME'
    export PATH=\$ORACLE_HOME/bin:\$PATH

    cd \$ORACLE_HOME

    ./runInstaller -silent \
        -waitforcompletion \
        oracle.install.option=INSTALL_DB_SWONLY \
        UNIX_GROUP_NAME=oinstall \
        INVENTORY_LOCATION='$ORA_INVENTORY' \
        ORACLE_HOME='$ORACLE_HOME' \
        ORACLE_BASE='$ORACLE_BASE' \
        oracle.install.db.InstallEdition=EE \
        oracle.install.db.OSDBA_GROUP=dba \
        oracle.install.db.OSOPER_GROUP=dba \
        oracle.install.db.OSBACKUPDBA_GROUP=backupdba \
        oracle.install.db.OSDGDBA_GROUP=dgdba \
        oracle.install.db.OSKMDBA_GROUP=kmdba \
        oracle.install.db.OSRACDBA_GROUP=racdba \
        DECLINE_SECURITY_UPDATES=true
    "
fi


echo "=== 3. Run Database root script ==="

if [ -f "$ROOT_MARKER" ]; then
    echo "Database root.sh already completed."
else
    "$ORACLE_HOME/root.sh"
    touch "$ROOT_MARKER"
fi

echo "=== 4. Verify Database software ==="

su - oracle -c "
export ORACLE_BASE='$ORACLE_BASE'
export ORACLE_HOME='$ORACLE_HOME'
export PATH=\$ORACLE_HOME/bin:\$PATH

sqlplus -v
"

echo "=== Database software installation completed ==="