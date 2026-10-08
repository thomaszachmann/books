# Chapter 4

**Kapitel 4: Kontrollierte Artefakt-Übergabe über Zonen- und Netzgrenzen**

Starts from Chapter 0. Leaves `demo-app:1.0.0` with its SBOM in `reg-ziel`, imported through quarantine, review and four-eyes release.

| File | Book step | Goes to |
|---|---|---|
| `bin/quarantaene-pruefen.sh` | Schritt 6 | `~/seclab/kap04/bin/` |
| `bin/freigeben.sh` | Schritt 7 | `~/seclab/kap04/bin/` |
| `bin/importieren.sh` | Schritt 8 | `~/seclab/kap04/bin/` |

The scripts default to `SCHLEUSE=$HOME/seclab/kap04/schleuse`. The sender and approver keys (`keys/*.key`) are generated with `openssl` in Schritte 4 and 7 and are not included.
