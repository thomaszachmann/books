# Vault — handover

> The "Known gaps" section is the one that matters. A handover claiming
> completeness teaches the next person nothing and misleads them at the
> first incident.

## Owner

| | |
|---|---|
| Primary | |
| Deputy | |
| Escalation out of hours | |

## What this Vault serves

Which systems depend on it, and what breaks if it is unavailable.

## Deployment

| | |
|---|---|
| Nodes | |
| Storage backend | |
| Seal type | |
| Version | |
| Config repository | |
| Terraform repository | |

## Unsealing

| | |
|---|---|
| Method | auto / manual |
| Recovery key holders | name — where kept — how to reach |
| Last rehearsed | |

## Backups

| | |
|---|---|
| Schedule | |
| Location | |
| Seal type recorded with each snapshot | yes / no |
| Restore last rehearsed | date, by whom |

## Audit

| | |
|---|---|
| Devices and their failure modes | |
| Shipped to | |
| Rotation | |

## Known gaps

Be specific enough that somebody could act on each line.

- 
- 

## Runbook

| Situation | Steps |
|---|---|
| Vault is sealed | |
| Quorum lost | |
| All requests failing | check audit devices and disk free space |
| KMS unreachable | |
| Root token needed | `operator generate-root` with recovery keys |
