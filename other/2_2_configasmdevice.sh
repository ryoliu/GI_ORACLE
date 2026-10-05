#!/bin/bash
set -euo pipefail

DATA_SERIAL=$(udevadm info --query=property --name=/dev/sdb | awk -F= '$1=="ID_SERIAL" {print $2}')
FRA_SERIAL=$(udevadm info --query=property --name=/dev/sdc | awk -F= '$1=="ID_SERIAL" {print $2}')

echo "DATA_SERIAL=$DATA_SERIAL"
echo "FRA_SERIAL=$FRA_SERIAL"

cat > /etc/udev/rules.d/99-oracle-asmdevices.rules <<EOF
SUBSYSTEM=="block", KERNEL=="sd*1", ENV{ID_SERIAL}=="$DATA_SERIAL", OWNER="grid", GROUP="asmdba", MODE="0660", SYMLINK+="asm-data"
SUBSYSTEM=="block", KERNEL=="sd*1", ENV{ID_SERIAL}=="$FRA_SERIAL", OWNER="grid", GROUP="asmdba", MODE="0660", SYMLINK+="asm-fra"
EOF

echo "=== Reload udev rules ==="
udevadm control --reload-rules
udevadm trigger

echo "=== Verify rules ==="
cat /etc/udev/rules.d/99-oracle-asmdevices.rules