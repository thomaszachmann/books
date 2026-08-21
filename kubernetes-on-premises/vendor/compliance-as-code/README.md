# Vendored control files

Two files, copied unmodified from ComplianceAsCode/content so that
Appendix D can be regenerated without a network:

    controls/bsi_sys_1_6.yml
    controls/bsi_app_4_4.yml

They carry the BSI requirement identifiers, titles and protection levels
for SYS.1.6 Containerisation and APP.4.4 Kubernetes, and cite the 2022
English edition of the IT-Grundschutz Compendium.

Licence: ComplianceAsCode/content is BSD-3-Clause. The requirement text
originates with the BSI; see the `source:` field in each file.

Refresh with `make vendor-refresh`, which needs a network. Do that
deliberately and read the diff: a requirement that appears or disappears
is a change to Appendix D, not a routine update.
