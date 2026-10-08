#!/usr/bin/env bash
# Tag 14, Szenario 5, nach der Behebung - Befehle wörtlich aus dem Buch.
bao kv get -field=db_user secret/webshop/config
bao operator raft list-peers
