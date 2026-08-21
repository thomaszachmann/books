# Chapter 7 — Hardening the Operating System

**State this chapter expects:** a node provisioned in Chapter 6, running
Rocky Linux 10 with `openscap-scanner` and `scap-security-guide`
installed. No cluster yet.

| Path | What it is |
|---|---|
| `scan.sh` | Produces the artifact: results, report and scan context |
| `exceptions.csv` | Template. Rules you knowingly do not meet, and what covers the risk |

## `exceptions.csv` has a `kind` column for a reason

Two kinds of exception look identical in a spreadsheet and are treated
very differently by an assessor:

- `impossible` — the platform cannot function with the rule applied.
  `sysctl_net_ipv4_ip_forward` under the STIG is the example in the
  chapter.
- `risk` — the rule could be met and you are choosing not to.
  `install_antivirus` is the example.

Conflating them makes the technical one look like a preference.

## This directory does not remediate anything

`scan.sh` evaluates. The remediation in the chapter is run by hand, from
a script you have read first, and only ever a few rules at a time. That
is the discipline the chapter is about, so the repository does not offer
a shortcut around it.
