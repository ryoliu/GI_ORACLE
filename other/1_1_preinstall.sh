#!/bin/bash
set -euo pipefail

PACKAGE="oracle-database-preinstall-19c"

GRID_BASE="/opt/grid/base"
GRID_HOME="/opt/grid/product/19.3.0.0/grid"

ORACLE_BASE="/opt/oracle"
ORACLE_HOME="/opt/oracle/product/19.3.0.0/db_1"

ORA_INVENTORY="/opt/oraInventory"
OINSTALL_GROUP="oinstall"

SOFTWARE_BASE="/software"
GI_SOFTWARE="/software/LINUX.X64_193000_grid_home.zip"
DB_SOFTWARE="/software/LINUX.X64_193000_db_home.zip"


echo "=== Install Oracle preinstall package ==="

if rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "$PACKAGE is already installed."
else
    yum install -y "$PACKAGE"
fi


echo "=== Verify Oracle groups ==="

for GROUP in oinstall dba; do
    if getent group "$GROUP" >/dev/null 2>&1; then
        echo "$GROUP group exists."
    else
        echo "ERROR: $GROUP group does not exist."
        exit 1
    fi
done


echo "=== Create ASM groups ==="

for GROUP in asmadmin asmdba asmoper racdba; do
    if getent group "$GROUP" >/dev/null 2>&1; then
        echo "$GROUP group already exists."
    else
        groupadd "$GROUP"
        echo "$GROUP group created."
    fi
done




echo "=== Configure users ==="

if ! id grid >/dev/null 2>&1; then
    useradd -g oinstall -G asmadmin,asmdba,asmoper grid
fi

usermod -aG dba,asmdba,racdba oracle
usermod -aG asmadmin,asmdba,asmoper,racdba,dba grid


echo "=== Verify kernel parameters ==="

sysctl kernel.shmmax
sysctl kernel.shmall
sysctl fs.file-max
sysctl kernel.sem


echo "=== Verify user limits ==="

echo "--- oracle ---"
su - oracle -c 'ulimit -n; ulimit -u'

echo "--- grid ---"
su - grid -c 'ulimit -n; ulimit -u'


echo "=== Create Oracle directories ==="

mkdir -p "$GRID_BASE"
mkdir -p "$GRID_HOME"
mkdir -p "$ORACLE_BASE"
mkdir -p "$ORACLE_HOME"
mkdir -p "$ORA_INVENTORY"

chown grid:"$OINSTALL_GROUP" "$GRID_BASE"
chown grid:"$OINSTALL_GROUP" "$GRID_HOME"
chown grid:"$OINSTALL_GROUP" "$ORA_INVENTORY"

chown oracle:"$OINSTALL_GROUP" "$ORACLE_BASE"
chown oracle:"$OINSTALL_GROUP" "$ORACLE_HOME"

chmod 775 "$GRID_BASE"
chmod 775 "$GRID_HOME"
chmod 775 "$ORACLE_BASE"
chmod 775 "$ORACLE_HOME"
chmod 775 "$ORA_INVENTORY"


echo "=== Configure software permissions ==="

chown root:"$OINSTALL_GROUP" "$SOFTWARE_BASE"
chmod 750  "$SOFTWARE_BASE"
chown root:"$OINSTALL_GROUP" "$GI_SOFTWARE"
chmod 640  "$GI_SOFTWARE"
chown root:"$OINSTALL_GROUP" "$DB_SOFTWARE"
chmod 640 "$DB_SOFTWARE"

echo "=== Configure oracle .bash_profile ==="

cat > /home/oracle/.bash_profile <<EOF
# .bash_profile

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

export DISPLAY=:0
export ORACLE_BASE=$ORACLE_BASE
export ORACLE_HOME=$ORACLE_HOME
export PATH=\$ORACLE_HOME/bin:\$PATH
EOF

chown oracle:"$OINSTALL_GROUP" /home/oracle/.bash_profile


echo "=== Configure grid .bash_profile ==="

cat > /home/grid/.bash_profile <<EOF
# .bash_profile

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

export DISPLAY=:0
export ORACLE_BASE=$GRID_BASE
export ORACLE_HOME=$GRID_HOME
export PATH=\$ORACLE_HOME/bin:\$PATH
EOF

chown grid:"$OINSTALL_GROUP" /home/grid/.bash_profile


echo "=== Verify oracle environment ==="

su - oracle -c 'echo "ORACLE_BASE=$ORACLE_BASE"'
su - oracle -c 'echo "ORACLE_HOME=$ORACLE_HOME"'


echo "=== Verify grid environment ==="

su - grid -c 'echo "ORACLE_BASE=$ORACLE_BASE"'
su - grid -c 'echo "ORACLE_HOME=$ORACLE_HOME"'


echo "PreInstall completed."