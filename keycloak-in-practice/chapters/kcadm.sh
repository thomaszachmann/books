# Source this, do not run it:  source chapters/kcadm.sh
#
# Chapter 3 types the admin CLI in full so you can see what it is.
# From Chapter 4 the book uses this function instead.
kcadm() {
  docker compose exec -T keycloak \
    /opt/keycloak/bin/kcadm.sh "$@"
}

# The realm's issuer URL. Chapter 4 introduces it; every later chapter
# that talks to the realm over HTTP uses it as $ISS. It lives here
# because shell variables do not survive a new terminal, and the labs
# are not read in one sitting.
ISS=https://sso.meridian.test/realms/meridian
