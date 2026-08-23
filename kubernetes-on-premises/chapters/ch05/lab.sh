#!/usr/bin/env bash
# Das Labor: sieben VMs, zwei Netze, ein Reset.
#
#   ./lab.sh nets        Netze definieren und starten
#   ./lab.sh up [name..] alle VMs, oder die genannten
#   ./lab.sh status      wer laeuft, mit welcher Adresse
#   ./lab.sh down        anhalten, Platten behalten
#   ./lab.sh reset       alles loeschen und von vorn
#
# ZUM UMFANG. Die Referenzarchitektur will sieben Maschinen. Auf
# einem Host mit vier Kernen laufen die nicht gleichzeitig, und das
# ist kein Grund, das Kapitel zu ueberspringen: jede Gruppe laesst
# sich einzeln fahren.
#
#   ./lab.sh up mirror lb          die Randmaschinen
#   ./lab.sh up cp1                ein Control-Plane-Knoten
#
# Was dabei NICHT geht, ist Kapitel 11 - ein zerstoerter Control
# Plane braucht drei echte Knoten, sonst uebt man Einzelknoten-
# Wiederherstellung und nennt sie Quorum. Der Umfang steht in
# VERSIONS.md; wer ihn unterschreitet, schreibt es in das
# Entscheidungsprotokoll.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
IMAGES="${IMAGES:-/var/lib/libvirt/images}"
BASE="${BASE:-$IMAGES/rocky10-base.qcow2}"
POOL="${POOL:-$IMAGES/k8s-lab}"
VIRSH="${VIRSH:-sudo virsh}"
QEMU_IMG="${QEMU_IMG:-sudo qemu-img}"

# name  vcpu  mem(MiB)  disk(G)  mac-suffix  netze
NODES="
cp1     2 2560 20 11 cluster
cp2     2 2560 20 12 cluster
cp3     2 2560 20 13 cluster
worker1 2 3072 30 21 cluster
worker2 2 3072 30 22 cluster
lb      1 1024 10 31 cluster
mirror  2 2048 40 41 both
"

node_field() { echo "$NODES" | awk -v n="$1" '$1==n{print $'"$2"'}'; }
all_names()  { echo "$NODES" | awk 'NF{print $1}'; }

# --------------------------------------------------------------- nets
nets() {
  for n in cluster mgmt; do
    $VIRSH net-info "k8s-$n" >/dev/null 2>&1 \
      || $VIRSH net-define "$HERE/net-$n.xml" >/dev/null
    $VIRSH net-start "k8s-$n" >/dev/null 2>&1
    $VIRSH net-autostart "k8s-$n" >/dev/null 2>&1
    printf '  %-12s %s\n' "k8s-$n" \
      "$($VIRSH net-info "k8s-$n" 2>/dev/null | awk '/Active/{print $2}')"
  done
  # Die Probe, die das Kapitel verlangt: hat das Cluster-Netz
  # wirklich keine NAT-Regel? Ein isoliertes Netz, das doch
  # maskiert, faellt erst in Kapitel 27 auf - also hier pruefen.
  if sudo nft list table ip nat 2>/dev/null | grep -q '10\.44\.0\.0/24.*masquerade'; then
    echo "  WARNUNG: k8s-cluster hat eine masquerade-regel." >&2
    echo "  Das Netz ist nicht isoliert. <forward/> im XML?" >&2
    return 1
  fi
  echo "  k8s-cluster: keine NAT-regel, isoliert"
}

# ------------------------------------------------------------ seed
seed_iso() { # $1 name
  local n="$1" d; d="$(mktemp -d)"
  cat > "$d/meta-data" <<EOF
instance-id: $n
local-hostname: $n
EOF
  # Ein einziger Schluessel, der des Hosts. Kein Passwort: Kapitel 7
  # haertet unter anderem die Passwortanmeldung weg, und ein Labor,
  # das man danach nur noch mit --disable-hardening betreten kann,
  # bringt niemandem etwas bei.
  cat > "$d/user-data" <<EOF
#cloud-config
hostname: $n
fqdn: $n.k8s.lab
ssh_pwauth: false
users:
  - name: lab
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "${PUBKEY:-$HOME/.ssh/id_rsa.pub}" 2>/dev/null || echo "ssh-rsa MISSING")
package_update: false
runcmd:
  - [ hostnamectl, set-hostname, $n ]
EOF
  $QEMU_IMG info "$BASE" >/dev/null 2>&1 || {
    echo "Basis-Image fehlt: $BASE" >&2; return 1; }
  sudo mkdir -p "$POOL"
  sudo cloud-localds "$POOL/$n-seed.iso" "$d/user-data" "$d/meta-data"
  rm -rf "$d"
}

# -------------------------------------------------------------- up
up_one() { # $1 name
  local n="$1" cpu mem disk mac nets
  cpu="$(node_field "$n" 2)"; mem="$(node_field "$n" 3)"
  disk="$(node_field "$n" 4)"; mac="$(node_field "$n" 5)"
  nets="$(node_field "$n" 6)"
  [ -z "$cpu" ] && { echo "unbekannter knoten: $n" >&2; return 2; }

  if $VIRSH dominfo "$n" >/dev/null 2>&1; then
    echo "  $n existiert schon"; return 0
  fi

  sudo mkdir -p "$POOL"
  $QEMU_IMG create -f qcow2 -F qcow2 -b "$BASE" \
    "$POOL/$n.qcow2" "${disk}G" >/dev/null
  seed_iso "$n" || return 1

  local netargs="--network network=k8s-cluster,mac=52:54:00:44:00:$mac,model=virtio"
  [ "$nets" = both ] && netargs="$netargs --network network=k8s-mgmt,mac=52:54:00:45:00:$mac,model=virtio"

  # shellcheck disable=SC2086
  sudo virt-install --name "$n" --memory "$mem" --vcpus "$cpu" \
    --disk "path=$POOL/$n.qcow2,format=qcow2,bus=virtio" \
    --disk "path=$POOL/$n-seed.iso,device=cdrom" \
    $netargs --os-variant rocky9 --graphics none --noautoconsole \
    --import >/dev/null 2>&1
  printf '  %-8s %s vCPU  %s MiB  %s G\n' "$n" "$cpu" "$mem" "$disk"
}

# ---------------------------------------------------------- status
status() {
  printf '  %-8s %-9s %s\n' NAME STATE ADDRESS
  for n in $(all_names); do
    local st ip
    st="$($VIRSH domstate "$n" 2>/dev/null || echo '-')"
    ip="$($VIRSH domifaddr "$n" 2>/dev/null | awk '/ipv4/{print $4; exit}')"
    printf '  %-8s %-9s %s\n' "$n" "$st" "${ip:--}"
  done
}

# ----------------------------------------------------------- reset
reset() {
  for n in $(all_names); do
    $VIRSH destroy "$n" >/dev/null 2>&1
    $VIRSH undefine "$n" --nvram >/dev/null 2>&1
  done
  sudo rm -f "$POOL"/*.qcow2 "$POOL"/*-seed.iso
  echo "  VMs weg, Platten weg. Netze bleiben - 'virsh net-destroy' fuer die."
  # Laut scheitern statt halb aufraeumen, wie in jedem Labor
  # dieser Reihe.
  local left
  left="$(ls "$POOL"/*.qcow2 2>/dev/null | wc -l | tr -d ' ')"
  [ "$left" = 0 ] || { echo "  UEBRIG: $left Platte(n) in $POOL" >&2; return 1; }
}

case "${1:-status}" in
  nets)   nets ;;
  up)     shift; nets >/dev/null
          for n in ${*:-$(all_names)}; do up_one "$n"; done ;;
  down)   for n in $(all_names); do $VIRSH shutdown "$n" >/dev/null 2>&1; done
          echo "  heruntergefahren, Platten behalten" ;;
  reset)  reset ;;
  status) status ;;
  *)      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
