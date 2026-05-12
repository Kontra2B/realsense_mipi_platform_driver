#!/bin/bash
cp -r images/$(cat jetpack_version)/rootfs/lib/modules/$(cat kernel_version) /lib/modules/
cp -r images/$(cat jetpack_version)/rootfs/boot/dtb /boot/dev/
cp -v images/$(cat jetpack_version)/rootfs/boot/vmlinu?-$(cat kernel_version) /boot/dev/
cp -v images/$(cat jetpack_version)/rootfs/boot/config-$(cat kernel_version) /boot/
kernel_image=$(ls -t /boot/dev/vmlinu?-$(cat kernel_version)|head -n 1)
ln -vsfT ${kernel_image} /boot/dev/Image
sudo depmod
update-initramfs -u -k $(cat kernel_version)
ln -vsfT /boot/initrd.img-$(cat kernel_version) /boot/dev/initrd
