# Exercise 1
Shell script that creates and runs an AMD64 Linux filesystem image using QEMU.

The system does not contain any user/session management or prompt for login information to access the filesystem.

User password might be asked in order to execute some tasks that need priviledges (eg.: mount).

The script runs in the current directory, and performs its task inside it, cleaning up any temporaries.

## Summary
The shell script will create an empty virtual disk image, partition it, and format it. Then it will use losetup and mount to access the first partition, and perform debootstrap and chroot to configure the system.

In order for the system to be bootable, I chose GRUB2 (instead of LILO) to install on the virtual disk image.

As the exercise requires no user login prompts, I chose to configure systemd to allow only 1 tty login, and that being automatically.
After that the <code>~/.profile</code> will output 'hello world'

## Also considered
#### _**Regarding the virtual image**_,
it would have been far easier to:
- just create a \<file> of enough size
- use <code>mkfs.ext4 \<file></code> on it
- mount it with <code>mount -o loop \<file> \<somewhere></code>
- use 'debootstrap \<somewhere>' and configure the image
- umount it and boot with:
    <code>qemu-system-x86_64 -kernel /boot/vmlinuz -drive file=<file>,format=raw -m 512m -append "root=/dev/sda"</code>
    
That would have worked, but wouldn't have been an entire full bootable disk image.

#### _**Regarding the no login prompt**_,
I also considered:
- replacing <code>/sbin/init</code> with my binary that performs printf 'hello world' to end there.
- booting in single user mode and performing an 'echo hello world' somewhere
But at the end I went with reducing the TTYs to only one, with autologin and an 'echo hello world' inside <code>~/.profile</code>

## Assumptions
- Script dependencies are already installed on the host system. To be sure execute <code>./dependencies.sh</code> before starting.
- The script will be executed in local filesystem, and not in a mounted network share.
  The reason for this is that at one point I use 'losetup' utility, and if used on Ubuntu 20 on a mounted network share, it will create a read-only /dev/loopX, impossible to deal with.
  Ubuntu 22 does not have this problem, and 'losetup' will work fine even on a mounted network share.

- The script will be executed in a filesystem with enough free space (eg.: ~2GB).

- The host machine will have one available loop device.
  Ubuntu 22 already consumes over 10 loop devices for snaps, and the default amount of loop devices is normally low (eg.: 16).
  I recommend using max_loop=256 as kernel parameter or in /etc/modprobe.conf as:
  option loop max_loop=256
---
Pablo Martikian

23 May 2022
