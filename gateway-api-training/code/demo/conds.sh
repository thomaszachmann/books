#!/usr/bin/env bash
# Zeigt die Conditions einer Gateway-API-Ressource kompakt an.
# Aufruf: conds.sh <kind> <name> [namespace]
#   GatewayClass: eigene Conditions · Gateway: zusätzlich pro Listener
#   Routes/Policies: Conditions pro Parent (status.parents / status.ancestors)
set -euo pipefail
kind="$1"; name="$2"; ns="${3:-default}"
nl='{"\n"}'
c="{range .conditions[*]}  {.type}={.status} ({.reason}): {.message}$nl{end}"
top="{range .status.conditions[*]}{.type}={.status} ({.reason}): {.message}$nl{end}"
case "$kind" in
  gatewayclass|gc)
    kubectl get gatewayclass "$name" -o jsonpath="$top" ;;
  gateway|gtw)
    lst="{range .status.listeners[*]}listener {.name}"
    lst+=" (attachedRoutes={.attachedRoutes}):$nl$c{end}"
    kubectl -n "$ns" get gateway "$name" -o jsonpath="$top$lst" ;;
  *)
    par="{range .status.parents[*]}parent {.parentRef.namespace}/"
    par+="{.parentRef.name}/{.parentRef.sectionName}:$nl$c{end}"
    anc="{range .status.ancestors[*]}ancestor {.ancestorRef.namespace}/"
    anc+="{.ancestorRef.name}/{.ancestorRef.sectionName}:$nl$c{end}"
    kubectl -n "$ns" get "$kind" "$name" -o jsonpath="$par$anc" ;;
esac
