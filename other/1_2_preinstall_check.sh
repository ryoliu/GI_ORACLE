#!/bin/bash
set -euo pipefail

DB_SOFTWARE="/software/LINUX.X64_193000_db_home.zip"
GI_SOFTWARE="/software/LINUX.X64_193000_grid_home.zip"

echo "=== Check package ==="
rpm -q oracle-database-preinstall-19c

echo "=== Check users ==="
id oracle
id grid

echo "=== Check groups ==="
getent group oinstall
getent group dba
getent group asmadmin
getent group asmdba
getent group asmoper
getent group racdba

echo "=== Check directories ==="
ls -ld \
    /opt/grid/base \
    /opt/grid/product/19.3.0.0/grid \
    /opt/oracle \
    /opt/oracle/product/19.3.0.0/db_1 \
    /opt/oraInventory

echo "=== Check installation files ==="

ls -lh "$DB_SOFTWARE"
ls -lh "$GI_SOFTWARE"

echo "=== Check oracle environment ==="
su - oracle -c 'echo "ORACLE_BASE=$ORACLE_BASE"'
su - oracle -c 'echo "ORACLE_HOME=$ORACLE_HOME"'

echo "=== Check grid environment ==="
su - grid -c 'echo "ORACLE_BASE=$ORACLE_BASE"'
su - grid -c 'echo "ORACLE_HOME=$ORACLE_HOME"'

echo "=== Check completed ==="