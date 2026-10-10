#!/usr/bin/env bash
set -euo pipefail
IDS=${1:?Vendor:Device-ID(s), kommasepariert}

cat > /etc/modules-load.d/vfio.conf <<'MOD'
vfio
vfio_iommu_type1
vfio_pci
MOD
cat > /etc/modprobe.d/ki-lab-gpu.conf <<CONF
blacklist nouveau
blacklist nvidiafb
options vfio-pci ids=${IDS}
softdep nouveau pre: vfio-pci
softdep nvidia pre: vfio-pci
CONF
update-initramfs -u -k all
