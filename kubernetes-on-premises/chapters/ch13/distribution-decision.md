# Distribution decision record

**Date:**
**Decided by:**
**Reviewed by:**

Fill this in on the day you decide. A record written afterwards contains
the same words and means something different — see Chapter 2.

## Decision

We will run ____________ on the cluster nodes.

## The ground

Tick exactly one. If none of them is true, the decision has no ground
yet and this file is not ready.

- [ ] A published checklist exists for it and somebody else maintains
      it. Which: ____________  version: ______  dated: ________
- [ ] No external assessment is expected. Chosen on operational
      grounds: ____________________
- [ ] The platform provider's evidence already covers our scope.
      Provider: ____________  their artefact: ____________

## What would change this decision

______________________________________________________________

Examples that have changed it for other people: an assessor appeared, a
STIG was published for the alternative, the provider changed, the
contract added a catalogue.

## The delta you owe

The checklist names a platform version. Ours is not that version.

  Checklist version: ____________
  Our version:       ____________
  Difference recorded on: ________  by: ____________

"We did not notice" is a worse answer than any number.

## What the profile does not do

If the distribution ships a hardening profile, list what it leaves to
you and who owns each. For RKE2's `profile: "cis"` that is at least:

  - sysctl file applied to the host          owner: ________
  - etcd user and group exist                owner: ________
  - network policies for our namespaces      owner: ________
  - automountServiceAccountToken: false      owner: ________
  - audit policy changed from level: None    owner: ________

The last one is the one that matters. A cluster with the profile on and
the shipped audit policy records nothing.

## Review

Reviewed again on: ________   still valid: yes / no
