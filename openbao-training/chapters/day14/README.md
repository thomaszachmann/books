# Day 14

**Tag 14: Wettkampf – Desaster-Drills**

Starts from Tag 13. Eight scenarios break the cluster on purpose; each ends when its check is green again.

The book works in `~/bao-lab/tag14`.

| File | Book step | Goes to |
|---|---|---|
| `vorbereitung.sh` | Vorbereitung | port-forward, admin login, exercise user `wettkampf`, safety snapshot `vorher.snap` |
| `wettkampf.hcl` | Vorbereitung | stdin of `bao policy write wettkampf -` |
| `szenario-1/stoerung.sh`, `diagnose.sh`, `behebung.sh` | Szenario 1 | pod and node failure |
| `szenario-2/stoerung.sh`, `diagnose.sh`, `behebung-a.sh`, `behebung-b.sh`, `peers.json` | Szenario 2 | quorum loss; `peers.json` is the body Behebung B writes into `openbao-0` |
| `szenario-3/stoerung.sh`, `diagnose.sh`, `behebung.sh` | Szenario 3 | unsealer unreachable |
| `szenario-4/stoerung.sh`, `symptome.sh`, `diagnose.sh`, `behebung.sh` | Szenario 4 | deleted secret |
| `szenario-5/stoerung.sh`, `diagnose.sh`, `behebung.sh`, `pruefung.sh` | Szenario 5 | snapshot restore into an empty cluster |
| `szenario-6/stoerung.sh`, `diagnose.sh`, `behebung.sh` | Szenario 6 | leaked token and SecretID |
| `szenario-7/stoerung.sh`, `diagnose.sh`, `behebung.sh` | Szenario 7 | expired TLS certificate, rolling renewal |
| `szenario-8/stoerung.sh`, `diagnose.sh`, `behebung.sh` | Szenario 8 | blocked audit device |

**`source` these files, in order, in one shell** — do not execute them. Later steps reuse variables from earlier ones (`BAO_TOKEN` from `vorbereitung.sh`, `A`, `ACC`, `V`). They are the book's blocks with a shebang and one source line added. The drills run as the exercise user `wettkampf` (`bao-admin` plus `wettkampf.hcl`); delete it afterwards, as the book says. Scenario 6 uses its own AppRole `leak-drill`, so the OpenTofu-managed role `webshop` stays without drift. Scenario 7 reuses `~/bao-lab/tls/openbao.ext` from Tag 7 and needs OpenSSL ≥ 3.4 (`-not_before`/`-not_after`).
