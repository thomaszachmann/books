# Chapter 6 - DELIBERATELY BROKEN.
#
# This is the mistake almost everyone makes with key/value version 2.
# The CLI path is meridian/tracking; the API path is
# meridian/data/tracking. Policies match the API path.
#
# Diagnose it with:
#   vault token capabilities <token> meridian/data/tracking

path "meridian/tracking" {
  capabilities = ["read"]
}
