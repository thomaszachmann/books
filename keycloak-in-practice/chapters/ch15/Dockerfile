# An optimised Keycloak image. Chapter 3 promised this and Chapter 15
# builds it.
#
# Build-time options belong here, in an image, where "did it take effect"
# is answerable by inspection. Setting one on a running --optimized
# server has no effect and prints no warning - which is Chapter 3's trap
# and the reason this file exists.
ARG KEYCLOAK_VERSION
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} AS builder

ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
COPY --from=builder /opt/keycloak/ /opt/keycloak/
ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", "--optimized"]
