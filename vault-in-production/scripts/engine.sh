# Welche Container-Laufzeit, und wie sie aufgerufen wird.
# Zum Einlesen gedacht:  . ./scripts/engine.sh
#
# Docker wird direkt benutzt. Wo nur podman liegt - Rocky, RHEL, SUSE -
# faehrt das Labor ROOTFUL, also ueber sudo. Der Grund ist nicht Bequem-
# lichkeit:
#
# Rootless podman bildet den aufrufenden Benutzer auf UID 0 im Container
# ab. Die gemounteten Verzeichnisse gehoeren dort dann root, der
# Vault-Prozess laeuft als "vault" und scheitert beim chown mit
#   chown: /vault/config: Permission denied
# Die Mount-Option ":U" soll das loesen und wird von podman-compose auch
# durchgereicht, hat in podman 5.8.2 aber keine Wirkung. "podman unshare
# chown" wirkt, entzieht die Verzeichnisse aber dem Host-Benutzer.
# Rootful podman entspricht ohnehin dem, was auf einem Server laeuft.
#
# ACHTUNG bei Aenderungen: dieses Snippet laeuft unter "set -o pipefail".
# "irgendwas | grep -q" ist dort eine Falle - grep beendet sich beim
# ersten Treffer, der Erzeuger bekommt SIGPIPE, die Pipeline gilt als
# gescheitert. Deshalb erst einsammeln, dann vergleichen.

_engine_version=$(docker --version 2>&1 || true)
case "$_engine_version" in
  *[Pp]odman*) _is_podman=yes ;;
  *)           _is_podman=no  ;;
esac
if ! command -v docker >/dev/null 2>&1; then _is_podman=yes; fi

if [ "$_is_podman" = yes ] && command -v podman >/dev/null 2>&1; then
  ENGINE="sudo podman"
  COMPOSE="sudo podman compose"
  ENGINE_NAME="podman (rootful)"
else
  ENGINE="docker"
  COMPOSE="docker compose"
  ENGINE_NAME="docker"
fi
export ENGINE COMPOSE ENGINE_NAME
