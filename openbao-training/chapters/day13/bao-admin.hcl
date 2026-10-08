# Mounts und Auth-Methoden
path "sys/mounts"           { capabilities = ["read","list"] }
path "sys/mounts/*"         { capabilities = ["create","read","update","delete","list"] }
path "sys/auth"             { capabilities = ["read"] }
path "sys/auth/*"           { capabilities = ["create","read","update","delete","sudo"] }
path "auth/*"               { capabilities = ["create","read","update","delete","list"] }

# Policies, Namespaces, Audit lesen
path "sys/policies/acl"     { capabilities = ["list"] }
path "sys/policies/acl/*"   { capabilities = ["create","read","update","delete","list"] }
path "sys/namespaces/*"     { capabilities = ["create","read","update","delete","list"] }
path "sys/audit"            { capabilities = ["read","sudo"] }

# Betrieb: Leases, Snapshots, Step-down, Raft-Status, Log-Level
path "sys/leases/*"         { capabilities = ["read","update","list","sudo"] }
path "sys/storage/raft/*"   { capabilities = ["read"] }
path "sys/step-down"        { capabilities = ["update","sudo"] }
path "sys/loggers*"         { capabilities = ["read","update","delete","sudo"] }

# Team-Namespaces (eine Ebene tief)
path "+/sys/mounts/*"       { capabilities = ["create","read","update","delete","list"] }
path "+/sys/auth/*"         { capabilities = ["create","read","update","delete","sudo"] }
path "+/sys/policies/acl/*" { capabilities = ["create","read","update","delete","list"] }
path "+/auth/*"             { capabilities = ["create","read","update","delete","list"] }

# Schlüssel- und Root-Operationen: nur Break-Glass
path "sys/rotate/*"         { capabilities = ["deny"] }
path "sys/generate-root-token/*" { capabilities = ["deny"] }
path "sys/raw/*"            { capabilities = ["deny"] }
