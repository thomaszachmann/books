# Which container runtime, and how it is called.
# Meant to be sourced:  . ./scripts/engine.sh
#
# Docker is used directly. Where there is only podman - Rocky, RHEL,
# SUSE - the lab runs ROOTFUL, through sudo. The reason is not
# convenience:
#
# Rootless podman maps the calling user to UID 0 in the container. The
# mounted directories then belong to root there, the Vault process runs
# as "vault" and fails at chown with
#   chown: /vault/config: Permission denied
# The mount option ":U" is meant to solve that and podman-compose passes
# it through, but in podman 5.8.2 it has no effect. "podman unshare
# chown" works, but takes the directories away from the host user.
# Rootful podman is what runs on a server anyway.
#
# CAREFUL when changing this: the snippet runs under "set -o pipefail".
# "something | grep -q" is a trap there - grep exits on the first match,
# the producer gets SIGPIPE, the pipeline counts as failed. So collect
# first, then compare.

_engine_version=$(docker --version 2>&1 || true)
case "$_engine_version" in
  *[Pp]odman*) _is_podman=yes ;;
  *)           _is_podman=no  ;;
esac
if ! command -v docker >/dev/null 2>&1; then _is_podman=yes; fi

if [ "$_is_podman" = yes ] && command -v podman >/dev/null 2>&1; then
  # sudo -E, not sudo: sudo cleans the environment, and VAULT_MOUNT_OPT
  # would never reach compose. The failure then looks exactly as if the
  # option had had no effect.
  ENGINE="sudo -E podman"
  COMPOSE="sudo -E podman compose"
  ENGINE_NAME="podman (rootful)"
  # Under SELinux a directory in the home carries the type user_home_t,
  # and a container may not write to it. ":z" relabels it to
  # container_file_t. Measured on Rocky 10.2:
  #   without :z   touch /vault/logs/probe  -> Permission denied
  #   with    :z   touch /vault/logs/probe  -> works
  # The error you see is "chown: ... Permission denied", and it
  # misleads: it is not a question of owners but of the SELinux type.
  # No AVC messages appear, because the policy suppresses them.
  # Written to follow a mode ("rw,z"); after a bare path use ":z".
  VAULT_MOUNT_OPT=",z"
else
  ENGINE="docker"
  COMPOSE="docker compose"
  ENGINE_NAME="docker"
  VAULT_MOUNT_OPT=""
fi
export ENGINE COMPOSE ENGINE_NAME VAULT_MOUNT_OPT
