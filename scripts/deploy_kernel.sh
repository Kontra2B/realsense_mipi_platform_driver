#!/bin/bash
set -e

# Display help message
if [ "$#" -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: $0 <JETPACK_VERSION> [TARGET] [USERNAME] [REMOTE_PATH] [REMOTE_BOOT_FOLDER]"
    echo ""
    echo "Package kernel modules, optionally copy them to the TARGET, update boot files and reboot the TARGET."
    echo ""
    echo "Arguments:"
    echo "  JETPACK_VERSION   JetPack version (e.g., 5.0.2, 5.1.2, 6.0, 6.1, 6.2, 6.2.1, 7.0, 7.1) - REQUIRED"
    echo "  TARGET            Target device hostname or IP address"
    echo "  USERNAME          SSH username for TARGET (default: administrator)"
    echo "  REMOTE_PATH       Remote path to copy files to (default: dev)"
    echo "  REMOTE_BOOT_FOLDER   Folder name under /boot on TARGET (default: dev)"
    echo ""
    echo "Example:"
    echo "  $0 6.2 192.168.1.100 - pack and copy to /home/administrator/dev, update /boot/dev and reboot TARGET"
    echo "  $0 6.2 192.168.1.100 nvidia - pack and copy to /home/nvidia/dev, update /boot/dev and reboot TARGET"
    echo "  $0 6.2 192.168.1.100 nvidia foo - pack and copy to /home/nvidia/foo, update /boot/dev and reboot TARGET"
    echo "  $0 6.2 192.168.1.100 nvidia foo bar - pack and copy to /home/nvidia/foo, update /boot/bar and reboot TARGET"
    exit 0
fi

# Set defaults
JETPACK_VERSION="$1"
TARGET="${2:-localhost}"
USERNAME="${3:-${USER}}"
REMOTE_PATH="${4:-dev}"
REMOTE_BOOT_FOLDER="${5:-dev}"
IMG_DIR="images/${JETPACK_VERSION}"
KERNEL_VERSION=$(cat ${IMG_DIR}/rootfs/kernel_version)
DEST_DIR="kernel_mod/${JETPACK_VERSION}"

[ -d ${DEST_DIR} ] && rm -rf ${DEST_DIR}
mkdir -p ${DEST_DIR}

echo "Kernel version: ${KERNEL_VERSION}"
echo "Creating ${DEST_DIR}/rootfs tarball..."
tar -cjf ${DEST_DIR}/rootfs.tar.bzip2 -C ${IMG_DIR}/rootfs \
	kernel_version \
	boot/System.map-${KERNEL_VERSION} \
	boot/vmlinuz-${KERNEL_VERSION} \
	boot/vmlinux-${KERNEL_VERSION} \
	boot/dtb \
	lib/modules/${KERNEL_VERSION} \
	|| true
echo "Copy install_to_kernel.sh to kernel_mod"
cp scripts/install_to_kernel.sh kernel_mod/

# Use SSH ControlMaster to reuse a single SSH connection
CONTROL_PATH="/tmp/ssh-control-${USERNAME}-${TARGET}"
ssh -MS "${CONTROL_PATH}" -fN ${USERNAME}@${TARGET}
ssh -S "${CONTROL_PATH}" ${USERNAME}@${TARGET} "rm -rf ${REMOTE_PATH}/${JETPACK_VERSION} && mkdir -p ${REMOTE_PATH}"
echo "Copying files to ${TARGET} host..."
scp -o ControlPath="${CONTROL_PATH}" -r kernel_mod/${JETPACK_VERSION} kernel_mod/install_to_kernel.sh ${USERNAME}@${TARGET}:${REMOTE_PATH}
echo "Setting permissions on remote host"
ssh -S "${CONTROL_PATH}" ${USERNAME}@${TARGET} "chmod +x ${REMOTE_PATH}/install_to_kernel.sh"
echo "Execute ./install_to_kernel.sh on ${TARGET} host"
ssh -tS "${CONTROL_PATH}" ${USERNAME}@${TARGET} "cd ${REMOTE_PATH} && ./install_to_kernel.sh ${JETPACK_VERSION} ${REMOTE_BOOT_FOLDER}"
ssh -S "${CONTROL_PATH}" -O exit ${USERNAME}@${TARGET} 2>/dev/null
