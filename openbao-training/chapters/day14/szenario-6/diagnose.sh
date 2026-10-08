#!/usr/bin/env bash
# Tag 14, Szenario 6, Diagnose - Befehle wörtlich aus dem Buch.
ACC=$(bao token lookup -format=json "$(cat geleakt.txt)" | jq -r .data.accessor)
bao token lookup -accessor $ACC | grep -E 'display_name|path|policies'
bao list auth/approle/role/webshop/secret-id         # SecretID-Accessors
bao write -field=hash sys/audit-hash/datei input="$(cat geleakt.txt)"  # Device aus Tag 12
