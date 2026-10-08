#!/usr/bin/env bash
# Tag 14, Szenario 4, Störung auslösen - Befehle wörtlich aus dem Buch.
bao kv put secret/webshop/config db_user=webshop db_pass=FALSCH   # Lab-Wert
bao kv delete secret/webshop/config
