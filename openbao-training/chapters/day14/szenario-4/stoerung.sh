#!/usr/bin/env bash
# Tag 14, Szenario 4, Störung auslösen - Befehle wörtlich aus dem Buch.
bao kv put -mount=secret webshop/config db_user=webshop db_pass=FALSCH   # Lab-Wert
bao kv delete -mount=secret webshop/config
