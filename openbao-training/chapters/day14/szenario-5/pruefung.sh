#!/usr/bin/env bash
# Tag 14, Szenario 5, nach der Behebung - Befehle wörtlich aus dem Buch.
export BAO_TOKEN=$(bao login -no-store -token-only -method=userpass \
  username=wettkampf password=lab-wk-pw)
bao kv get -mount=secret -field=db_user webshop/config
bao operator raft list-peers
