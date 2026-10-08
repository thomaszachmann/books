#!/usr/bin/env bash
# Tag 14, Szenario 4, Diagnose - Befehle wörtlich aus dem Buch.
bao kv metadata get -mount=secret webshop/config
bao kv metadata get -format=json -mount=secret webshop/config \
  | jq '.data.current_version'
