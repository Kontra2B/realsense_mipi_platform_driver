#!/bin/bash
set -e

# Display help message
if [ "$#" -lt 1 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      echo "Usage: $0 <JETPACK_VERSION> [BOOT_FOLDER]"
      echo ""
      echo "Update the kernel modules and boot files on the local device for a specific JetPack version."
      echo ""
      echo "Arguments:"
      echo "  JETPACK_VERSION   JetPack version (e.g., 5.0.2, 5.1.2, 6.0, 6.1, 6.2, 6.2.1, 7.0, 7.1)"
      echo "  BOOT_FOLDER       Folder name under /boot to copy Image (default: dev)"
      echo ""
      echo "Example:"
      echo "  $0 6.2 foo"
      exit 0
fi

JETPACK_VERSION="$1"
FOLDER="${2:-dev}"

echo "Extracting rootfs tarball..."
tar -C "${JETPACK_VERSION}" -xf ${JETPACK_VERSION}/rootfs.tar.*

KERNEL_VERSION=$(cat kernel_version)
MODULES_DIR="/lib/modules/${KERNEL_VERSION}"

echo "Installing "${KERNEL_VERSION}" kernel files for JetPack ${JETPACK_VERSION}..."
echo "Install new modules to ${MODULES_DIR}"
sudo cp -r ${JETPACK_VERSION}${MODULES_DIR} /lib/modules/
[ -d /boot/${FOLDER} ] || sudo mkdir /boot/${FOLDER}
echo "Install new device tree files to /boot/${FOLDER}/dtb"
sudo cp -r ${JETPACK_VERSION}/boot/dtb /boot/${FOLDER}/
echo "Install new image to /boot/${FOLDER}"
sudo cp ${JETPACK_VERSION}/boot/vmlinu?-${KERNEL_VERSION} /boot/${FOLDER}/
KERNEL_IMAGE=$(ls -t /boot/${FOLDER}/vmlinu?-${KERNEL_VERSION} 2>/dev/null | head -n 1)
sudo ln -sfT /boot/${FOLDER}/${KERNEL_IMAGE} /boot/${FOLDER}/Image

sudo depmod
sudo update-initramfs -ck ${KERNEL_VERSION}
sudo ln -sfT /boot/initrd.img-${KERNEL_VERSION} /boot/${FOLDER}/initrd
sudo reboot
