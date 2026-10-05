#!/bin/bash
set -euo pipefail

GRID_HOME="/opt/grid/product/19.3.0.0/grid"
ORACLE_BASE="/opt/oracle"
ORACLE_HOME="/opt/oracle/product/19.3.0.0/db_1"


echo "=== 1. Check Oracle Restart and ASM ==="

"$GRID_HOME/bin/crsctl" check has

su - grid -c "
export ORACLE_HOME='$GRID_HOME'
export ORACLE_SID=+ASM
export PATH=\$ORACLE_HOME/bin:\$PATH

crsctl status resource -t
srvctl status asm
asmcmd lsdg
"


echo "=== 2. Database name ==="

read -p "Enter DB_NAME: " DB_NAME

if [ -z "$DB_NAME" ]; then
    echo "ERROR: DB_NAME cannot be empty."
    exit 1
fi


echo "=== 3. Check Database ==="

if su - grid -c "
export ORACLE_HOME='$GRID_HOME'
export PATH=\$ORACLE_HOME/bin:\$PATH

srvctl config database -db '$DB_NAME'
" >/dev/null 2>&1; then

    echo "Database $DB_NAME already exists."
    echo "Skip DBCA."

else

    echo "Database $DB_NAME does not exist."

    read -s -p "Enter SYS/SYSTEM password: " DB_PASSWORD
    echo

    if [ -z "$DB_PASSWORD" ]; then
        echo "ERROR: Password cannot be empty."
        exit 1
    fi

    echo "=== 4. Create Database ==="

    su - oracle -c "
    export ORACLE_BASE='$ORACLE_BASE'
    export ORACLE_HOME='$ORACLE_HOME'
    export PATH=\$ORACLE_HOME/bin:\$PATH
    export DISPLAY=:0

    dbca -silent -createDatabase \
        -templateName General_Purpose.dbc \
        -gdbname '$DB_NAME' \
        -sid '$DB_NAME' \
        -databaseConfigType SINGLE \
        -createAsContainerDatabase false \
        -sysPassword '$DB_PASSWORD' \
        -systemPassword '$DB_PASSWORD' \
        -storageType ASM \
        -datafileDestination +DATA \
        -useOMF true \
        -recoveryAreaDestination +FRA \
        -recoveryAreaSize 8256 \
        -enableArchive true \
        -characterSet AL32UTF8 \
        -emConfiguration NONE
    "

fi


echo "=== 5. Check Database status ==="

if su - grid -c "
export ORACLE_HOME='$GRID_HOME'
export PATH=\$ORACLE_HOME/bin:\$PATH

srvctl status database -db '$DB_NAME'
" | grep -q "is running"; then

    echo "Database $DB_NAME is running."

else

    echo "Starting database $DB_NAME..."

    su - grid -c "
    export ORACLE_HOME='$GRID_HOME'
    export PATH=\$ORACLE_HOME/bin:\$PATH

    srvctl start database -db '$DB_NAME'
    "
fi


echo "=== 6. Verify Oracle Restart ==="

"$GRID_HOME/bin/crsctl" check has


echo "=== 7. Verify Resources ==="

su - grid -c "
export ORACLE_HOME='$GRID_HOME'
export ORACLE_SID=+ASM
export PATH=\$ORACLE_HOME/bin:\$PATH

crsctl status resource -t
"


echo "=== 8. Verify ASM ==="

su - grid -c "
export ORACLE_HOME='$GRID_HOME'
export ORACLE_SID=+ASM
export PATH=\$ORACLE_HOME/bin:\$PATH

srvctl status asm
asmcmd lsdg
"


echo "=== 9. Verify Listener ==="

su - grid -c "
export ORACLE_HOME='$GRID_HOME'
export PATH=\$ORACLE_HOME/bin:\$PATH

srvctl status listener
"


echo "=== 10. Verify Database ==="

su - grid -c "
export ORACLE_HOME='$GRID_HOME'
export PATH=\$ORACLE_HOME/bin:\$PATH

srvctl config database -db '$DB_NAME'
srvctl status database -db '$DB_NAME'
"


echo "=== 11. Verify Database with SQLPlus ==="

su - oracle -c "
export ORACLE_SID='$DB_NAME'
export ORACLE_HOME='$ORACLE_HOME'
export PATH=\$ORACLE_HOME/bin:\$PATH

sqlplus -s / as sysdba <<EOF
set pagesize 100
set linesize 200

select instance_name, status, database_status
from v\\\$instance;

select name, open_mode, log_mode
from v\\\$database;

show parameter db_recovery_file_dest

exit
EOF
"


echo "=== Database creation and verification completed ==="