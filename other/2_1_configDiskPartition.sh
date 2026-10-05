lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT

##create partition
fdisk /dev/sdb

n
p
1
Enter
Enter
w

lsblk

udevadm info --query=property --name=/dev/sdb | grep ID_SERIAL
udevadm info --query=property --name=/dev/sdc | grep ID_SERIAL


vi /etc/udev/rules.d/99-oracle-asmdevices.rules

SUBSYSTEM=="block", KERNEL=="sd*1", ENV{ID_SERIAL}=="VBOX_HARDDISK_VB8de520e7-70d5383a", OWNER="grid", GROUP="asmdba", MODE="0660", SYMLINK+="asm-data"
SUBSYSTEM=="block", KERNEL=="sd*1", ENV{ID_SERIAL}=="VBOX_HARDDISK_VB6cf2d1e4-212dc807", OWNER="grid", GROUP="asmdba", MODE="0660", SYMLINK+="asm-fra"

udevadm control --reload-rules
udevadm trigger

ls -l /dev/asm-*


ls -l /dev/asm-data
ls -l /dev/asm-fra
