#!/usr/bin/env bash
# Ubuntu 24.04 LTS cloud image 기반 Proxmox template (VMID 901)
# cockpit VM(102)의 clone 원본. walle에서 root/sudo로 실행.
set -euo pipefail

TEMPLATE_VMID=901
CLOUD_IMAGE="noble-server-cloudimg-amd64.img"
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/${CLOUD_IMAGE}"
STORAGE="local-lvm"
TMP_DIR="/tmp/ubuntu-template-$$"

mkdir -p "${TMP_DIR}"

echo "Downloading Ubuntu 24.04 LTS cloud image..."
wget -q "${CLOUD_IMAGE_URL}" -O "${TMP_DIR}/${CLOUD_IMAGE}"

# qemu-guest-agent 주입 (libguestfs-tools 필요 — 없으면 cloud-init으로 VM 측에서 설치)
if command -v virt-customize >/dev/null 2>&1; then
  echo "Injecting qemu-guest-agent via virt-customize..."
  virt-customize -a "${TMP_DIR}/${CLOUD_IMAGE}" --install qemu-guest-agent
else
  echo "WARN: virt-customize 미설치 — qemu-guest-agent는 VM cloud-init으로 설치 필요"
fi

echo "Creating Ubuntu template VM (ID: ${TEMPLATE_VMID})..."
qm create ${TEMPLATE_VMID} \
  --name "ubuntu-2404-template" \
  --cores 2 \
  --memory 2048 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --agent enabled=1

echo "Importing disk to ${STORAGE}..."
qm importdisk ${TEMPLATE_VMID} "${TMP_DIR}/${CLOUD_IMAGE}" ${STORAGE}

qm set ${TEMPLATE_VMID} \
  --scsi0 ${STORAGE}:vm-${TEMPLATE_VMID}-disk-0 \
  --ide2 ${STORAGE}:cloudinit \
  --boot c \
  --bootdisk scsi0 \
  --serial0 socket \
  --vga serial0

echo "Converting to template..."
qm template ${TEMPLATE_VMID}

rm -rf "${TMP_DIR}"
echo "Ubuntu 24.04 LTS template (VM ${TEMPLATE_VMID}) created."
