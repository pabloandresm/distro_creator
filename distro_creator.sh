#!/bin/bash
#
# Creator: Pablo Martikian (pablomartikian@hotmail.com)
#
# Exercise 1:
# This script will create and run an fully bootable AMD64 linux image
# filesystem using QEMU, that will print "hello world" after startup.
#

IMAGE=virtual_disk.img
LOCALPART1=rootfs
QEMU_LAUNCH="qemu-system-x86_64 -drive file=$IMAGE,format=raw -m 512m"

#for UBUNTU debootstrap
#IMAGESIZE=4000m
#DEBOOTSTRAP="--include=systemd,console-setup,grub2,linux-image-generic --components=main,restricted,universe,multiverse --extra-suites=jammy-updates,jammy-backports,jammy-security jammy $LOCALPART1 http://archive.ubuntu.com/ubuntu"

#for DEBIAN debootstrap
IMAGESIZE=2000m
DEBOOTSTRAP="--include=console-setup,grub2,linux-image-amd64 --components=main,contrib,non-free --extra-suites=stable-updates stable $LOCALPART1"

LOOP_DEVICE=
# run() & cleanup() will execute commands and cleanup in case of failure
trap cleanup INT
cleanup() {
    sudo umount -R -q $LOCALPART1
    if [ "$?" -eq 0 ]; then command rm -Rf $LOCALPART1 2>/dev/null; fi
    if [ ! -z "$LOOP_DEVICE" ]; then sudo losetup -d $LOOP_DEVICE 2>/dev/null; fi
    if [ "$1" = "y" ]; then command rm -f $IMAGE; fi
}
run() { "$@"; err=$?; if [ "$err" -ne 0 ]; then echo "Command '$*' failed with error $err"; cleanup "y"; exit $err; fi }

# We do not want to lose previous work, so we inform the user.
if [ -f "$IMAGE" ]; then
    echo "File '$IMAGE' already exists. Delete it if you want to continue."
    exit 1
fi

start_time=`date +%s`

# we create the virtual filesystem
echo "Creating filesystem ----------------------------------"
run truncate -s $IMAGESIZE $IMAGE

echo " - MBR..."
printf ",\nwrite\n" | run sfdisk -q $IMAGE

echo " - 1st Partition..."
run mkdir $LOCALPART1
run sudo losetup -P -f $IMAGE
LOOP_DEVICE=`losetup -j $IMAGE -O NAME -n`

echo " - Ext4 formatting..."
run sudo mkfs.ext4 -q ${LOOP_DEVICE}p1

echo " - Mounting..."
# I use "data=writeback,barrier=0,commit=600,noatime,nodiratime" for speed performance!
run sudo mount -o loop,data=writeback,barrier=0,commit=600,noatime,nodiratime ${LOOP_DEVICE}p1 $LOCALPART1

# Bootstrapping the system
echo "Bootstrapping system ---------------------------------"
run sudo debootstrap --arch amd64 $DEBOOTSTRAP
run sudo mount -o bind /dev $LOCALPART1/dev
run sudo mount -o bind /proc $LOCALPART1/proc
#run sudo mount -o bind /sys $LOCALPART1/sys
# we avoid mounting /sys because it will generate grub entries for the host kernels

# update-grub
echo "Update GRUB ------------------------------------------"
run sudo sed -i 's/quiet/console=tty1 console=ttyS0 root=\/dev\/sda1/g' $LOCALPART1/etc/default/grub
run sudo chroot $LOCALPART1 /usr/sbin/update-grub

# System config
echo "System configuration ---------------------------------"
echo " - LOCALE: en_US.UTF-8..."
echo LANG="en_US.UTF-8" | sudo tee $LOCALPART1/etc/default/locale
echo " - fstab..."
echo "/dev/sda1 / ext4 defaults,errors=remount-ro 0 1" | sudo tee $LOCALPART1/etc/fstab
echo " - root password: welcome..."
printf "welcome\nwelcome\n" | sudo chroot $LOCALPART1 passwd
echo " - create user: user1..."
run sudo chroot $LOCALPART1 useradd -m -s /bin/bash user1
echo " - user1 password: welcome..."
printf "welcome\nwelcome\n" | sudo chroot $LOCALPART1 passwd user1
echo " - Disable getty-static.service..."
run sudo chroot $LOCALPART1 systemctl mask getty-static.service
echo " - Override agetty for user1 (tty1 & ttyS0)..."
run sudo chroot $LOCALPART1 mkdir /etc/systemd/system/getty\@tty1.service.d
printf "[Service]\nExecStart=\nExecStart=-/sbin/agetty -a user1 --noclear %%I \$TERM\n" | sudo tee $LOCALPART1/etc/systemd/system/getty\@tty1.service.d/override.conf
run sudo chroot $LOCALPART1 mkdir /etc/systemd/system/serial-getty\@ttyS0.service.d
printf "[Service]\nExecStart=\nExecStart=-/sbin/agetty -a user1 --noclear %%I \$TERM\n" | sudo tee $LOCALPART1/etc/systemd/system/serial-getty\@ttyS0.service.d/override.conf
echo " - hello world..."
printf "\necho hello world\n" | sudo tee -a $LOCALPART1/home/user1/.profile

# GRUB2 Bootloader
echo "GRUB2 Bootloader--------------------------------------"
run sudo chroot $LOCALPART1 grub-install -s --modules "part_msdos" $LOOP_DEVICE

cleanup

end_time=`date +%s`
echo "ELAPSED: " $((end_time-start_time)) "seconds."
echo "DONE!"
echo "LAUNCHING WITH: $QEMU_LAUNCH"

$QEMU_LAUNCH

exit $?
