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
  # sudo -E, nicht sudo: sudo raeumt die Umgebung auf, und VAULT_MOUNT_OPT
  # kaeme sonst nie bei compose an. Der Fehler sieht dann exakt so aus, als
  # haette die Option nicht gewirkt.
  ENGINE="sudo -E podman"
  COMPOSE="sudo -E podman compose"
  ENGINE_NAME="podman (rootful)"
  # Unter SELinux traegt ein Verzeichnis im Home den Typ user_home_t, und
  # ein Container darf darauf nicht schreiben. ":z" etikettiert es auf
  # container_file_t um. Gemessen auf Rocky 10.2:
  #   ohne :z   touch /vault/logs/probe  -> Permission denied
  #   mit  :z   touch /vault/logs/probe  -> geht
  # Der Fehler, den man dabei sieht, lautet "chown: ... Permission
  # denied" und fuehrt in die Irre: es ist keine Frage der Besitzer,
  # sondern des SELinux-Typs. AVC-Meldungen erscheinen nicht, weil die
  # Regel sie unterdrueckt.
  VAULT_MOUNT_OPT=",z"
else
  ENGINE="docker"
  COMPOSE="docker compose"
  ENGINE_NAME="docker"
  VAULT_MOUNT_OPT=""
fi
export ENGINE COMPOSE ENGINE_NAME VAULT_MOUNT_OPT
