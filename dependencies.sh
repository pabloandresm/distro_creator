#!/bin/bash
#
# Creator: Pablo Martikian (pablomartikian@hotmail.com)
#
# Althouth the dependencies are mostly already installed on host systems,
#   let' s make sure of that.

sudo apt-get -y install mount coreutils e2fsprogs debootstrap sed qemu-system-x86 fdisk

exit $?
