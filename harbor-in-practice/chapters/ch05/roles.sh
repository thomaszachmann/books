#!/usr/bin/env bash
# Harbor's project role IDs, and the one thing you must not do with them.
#
# The IDs are the order the roles were added to Harbor. They are NOT a
# ranking. In order of actual power the list runs 1, 4, 2, 3, 5:
#
#   1  projectAdmin    everything, including members, robots and logs
#   4  maintainer      everything above except members, robots, logs
#   2  developer       push and pull; CANNOT delete, CANNOT start a scan
#   3  guest           pull; sees members, robots and labels
#   5  limitedGuest    pull; sees none of those
#
# So `[ "$role" -le 2 ]` to mean "may push" silently makes every
# maintainer read-only, and `[ "$role" -ge 3 ]` to mean "read only"
# silently grants push to nobody while denying it to maintainers.
set -euo pipefail

role_name() {
  case "$1" in
    1) echo projectAdmin ;;
    2) echo developer    ;;
    3) echo guest        ;;
    4) echo maintainer   ;;
    5) echo limitedGuest ;;
    *) echo "unknown role id: $1" >&2; return 1 ;;
  esac
}

# Seeing a thing and changing it are different rights, and the roles
# differ in exactly that gap. Every set below is transcribed from
# src/common/rbac/project/rbac_role.go at the pinned version.
may_push()        { case "$1" in 1|2|4)   return 0 ;; *) return 1 ;; esac; }
may_pull()        { case "$1" in 1|2|3|4|5) return 0 ;; *) return 1 ;; esac; }
may_delete()      { case "$1" in 1|4)     return 0 ;; *) return 1 ;; esac; }
may_start_scan()  { case "$1" in 1|4)     return 0 ;; *) return 1 ;; esac; }
may_read_scan()   { case "$1" in 1|2|3|4|5) return 0 ;; *) return 1 ;; esac; }
may_see_members() { case "$1" in 1|2|3|4) return 0 ;; *) return 1 ;; esac; }
may_edit_members(){ case "$1" in 1)       return 0 ;; *) return 1 ;; esac; }
may_see_robots()  { case "$1" in 1|2|3|4) return 0 ;; *) return 1 ;; esac; }
may_make_robots() { case "$1" in 1)       return 0 ;; *) return 1 ;; esac; }
may_read_logs()   { case "$1" in 1)       return 0 ;; *) return 1 ;; esac; }

# Sourced as a library, or run to print the table. The guard is written
# defensively because BASH_SOURCE does not exist in zsh, which is the
# default shell on macOS - and a reader sourcing this file should get a
# library, not an unbound-variable error.
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  fmt='%-3s %-13s %-5s %-7s %-6s %-9s %-9s %-7s %s\n'
  # shellcheck disable=SC2059
  printf "$fmt" id name push delete scan+ members+ robots+ see-mem logs
  for r in 1 4 2 3 5; do
    y() { if "$1" "$r"; then printf 'yes'; else printf 'no'; fi; }
    # shellcheck disable=SC2059
    printf "$fmt" "$r" "$(role_name "$r")" \
      "$(y may_push)" "$(y may_delete)" "$(y may_start_scan)" \
      "$(y may_edit_members)" "$(y may_make_robots)" \
      "$(y may_see_members)" "$(y may_read_logs)"
  done
  echo
  echo "A '+' means change it. Seeing is a different right: guest and"
  echo "developer see members and robots, and can change neither."
fi
