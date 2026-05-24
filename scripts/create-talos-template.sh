#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_VMID=900
ISO_NAME="metal-amd64.iso"
STORAGE="local-lvm"

echo "Creating Talos template VM (ID: ${TEMPLATE_VMID})..."

qm create ${TEMPLATE_VMID} \
  --name "talos-template" \
  --bios seabios \
  --cores 2 \
  --memory 1024 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --scsi0 ${STORAGE}:10 \
  --cdrom local:iso/${ISO_NAME} \
  --boot order=scsi0 \
  --agent enabled=1

echo "Converting to template..."
qm template ${TEMPLATE_VMID}

echo "Talos template (VM ${TEMPLATE_VMID}) created."
