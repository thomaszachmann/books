#!/usr/bin/env bash
# Stop the lab and delete its state.
#
# Why this is not simply "rm -rf cluster/data*":
#
# Vault creates cluster/dataN/raft inside the container, as the user
# "vault" (UID 100), with mode 0700. On the host the directory then
# belongs to some unrelated account - on Ubuntu "stat" shows
# "dhcpcd" - and the calling user may neither enter nor delete it:
#
#   rm: cannot remove 'cluster/data1/raft': Permission denied
#
# make reset used to stop exactly here. The treacherous part was not
# the error but what it left behind: init.json was already gone, the
# Raft directories were not. "make up && make init" then carried on
# with old state, and the lab behaved inexplicably.
#
# So the deletion runs from a throwaway container that runs as root
# and gets the same directories mounted. That needs no sudo on the
# host and works under Docker as under rootful podman.
set -euo pipefail

cd "$(dirname "$0")/.."
. ./scripts/engine.sh

$COMPOSE down -v >/dev/null 2>&1 || true

# config belongs on the list: cluster-up.sh skips node configurations
# that already exist. If one is left behind, every change to
# cluster-up.sh silently has no effect - you change the telemetry
# stanza, restart, and keep measuring the old state.
# tls stays on purpose: regenerating certificates costs time and
# changes nothing in any chapter.
TARGETS="data1 data2 data3 init.json config"

# Fast path: whatever belongs to the host user is gone at once.
for t in $TARGETS; do rm -rf "cluster/$t" 2>/dev/null || true; done
rm -rf logs/* 2>/dev/null || true

# What is left belongs to the container. Delete it from a container.
# logs/ too: the audit log is written by UID 100 and survives the
# fast path silently - a second run then counts every line twice.
leftover=""
for t in $TARGETS; do [ -e "cluster/$t" ] && leftover="$leftover $t"; done
[ -n "$(ls -A logs 2>/dev/null)" ] && leftover="$leftover logs"

if [ -n "$leftover" ]; then
  $ENGINE run --rm \
    -v "$PWD/logs:/logs${VAULT_MOUNT_OPT:+:${VAULT_MOUNT_OPT#,}}" \
    docker.io/library/alpine:3.20 sh -c 'rm -rf /logs/* /logs/.[!.]*' \
    >/dev/null 2>&1 || true
  # VAULT_MOUNT_OPT is ",z" on SELinux hosts, written to follow "rw".
  # Here there is no "rw", so it becomes ":z". Appending ",z" directly
  # makes the mount point "/reset,z", and the container finds no
  # /reset to delete from.
  $ENGINE run --rm \
    -v "$PWD/cluster:/reset${VAULT_MOUNT_OPT:+:${VAULT_MOUNT_OPT#,}}" \
    docker.io/library/alpine:3.20 \
    sh -c "cd /reset && rm -rf $TARGETS" \
    >/dev/null 2>&1 || true
fi

# Fail loudly rather than clean up halfway.
still=""
for t in $TARGETS; do [ -e "cluster/$t" ] && still="$still cluster/$t"; done
[ -n "$(ls -A logs 2>/dev/null)" ] && still="$still logs/*"

if [ -n "$still" ]; then
  echo "reset incomplete, left over:$still" >&2
  echo "The lab is now in a mixed state - 'make up' would carry on" >&2
  echo "with old Raft state. Remove these by hand with elevated" >&2
  echo "rights, then try again." >&2
  exit 1
fi

echo "Gone. 'make up' starts over."
