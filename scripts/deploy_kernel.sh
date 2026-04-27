#!/bin/bash
set -e

# Display help message
if [ "$#" -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: $0 <JETPACK_VERSION> [TARGET_HOST] [REMOTE_USER] [COPY_TO_PATH] [TARGET_FOLDER]"
    echo ""
    echo "Package kernel modules, optionally copy them to the TARGET, update boot files and reboot the TARGET."
    echo ""
    echo "Arguments:"
    echo "  JETPACK_VERSION   JetPack version (e.g., 5.0.2, 5.1.2, 5.1.6, 6.0, 6.1, 6.2, 6.2.1, 6.2.2, 7.0, 7.1) - REQUIRED"
	echo "  TARGET_HOST       Target host name or IP address (default: localhost)"
    echo "  REMOTE_USER       Username on target host (default: administrator)"
    echo "  COPY_TO_PATH      Remote path to copy files to (default: dev)"
    echo "  TARGET_FOLDER     Folder name on target host to install kernel files to (default: /boot/dev)"
    echo ""
    echo "Example:"
    echo "  $0 6.2 - pack and copy to localhost to /tmp/kernel_mod/dev folder, install to localhost /boot/dev/ and reboot localhost"
    echo "  $0 6.2 192.168.1.100 nvidia - pack and copy to host 192.168.1.100 to /tmp/kernel_mod/dev, install to /boot/dev/ and reboot remote host"
    echo "  $0 6.2 host.domain nvidia foo - pack and copy to host host.domain to /tmp/kernel_mod/foo, install to /boot/dev/ and reboot remote host"
    echo "  $0 6.2 192.168.1.100 nvidia foo /boot/bar - pack and copy to host 192.168.1.100 to /tmp/kernel_mod/foo, install to ./bar and reboot remote host"
    exit 0
fi

# Set defaults
JETPACK_VERSION="$1"
TARGET="${2:-localhost}"
USERNAME="${3:-${USER}}"
REMOTE_PATH="${4:-dev}"
REMOTE_FOLDER="${5:-/boot/dev}"
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
ssh -S "${CONTROL_PATH}" "${USERNAME}@${TARGET}" "rm -rf /tmp/kernel_mod/${REMOTE_PATH}/${JETPACK_VERSION} && mkdir -p /tmp/kernel_mod/${REMOTE_PATH}"
echo "Copying files to ${TARGET} host to /tmp/kernel_mod/${REMOTE_PATH}..."
scp -o ControlPath="${CONTROL_PATH}" -r kernel_mod/${JETPACK_VERSION} kernel_mod/install_to_kernel.sh "${USERNAME}@${TARGET}:/tmp/kernel_mod/${REMOTE_PATH}"
echo "Setting permissions on remote host"
ssh -S "${CONTROL_PATH}" "${USERNAME}@${TARGET}" "chmod +x /tmp/kernel_mod/${REMOTE_PATH}/install_to_kernel.sh"
echo "Execute /tmp/kernel_mod/${REMOTE_PATH}/install_to_kernel.sh on ${TARGET} host"
ssh -tS "${CONTROL_PATH}" "${USERNAME}@${TARGET}" "cd /tmp/kernel_mod/${REMOTE_PATH} && ./install_to_kernel.sh ${JETPACK_VERSION} ${REMOTE_FOLDER}"
ssh -S "${CONTROL_PATH}" -O exit 2>/dev/null
