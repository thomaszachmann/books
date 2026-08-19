# Chapter 06 — Robot Accounts

**Starting state:** Chapter 5 finished. `platform` exists, four members.

**What this chapter builds:** a credential that can do exactly two
things, and a check that tells you before it expires rather than after.

```bash
./make-robot.sh platform ci-push 30 pull push
./expiring-robots.sh 14        # non-zero if any expire within 14 days
```

`make-robot.sh` warns when you ask for `push` without `pull`. A build
that pulls a cache layer before pushing needs both, and the failure
appears at a step the robot is otherwise allowed to perform.

`expiring-robots.sh` filters `select(.expires_at > 0)` before comparing.
Harbor uses `-1` for "never expires", and `-1` is smaller than any
threshold — so without the filter every non-expiring robot reports as
due, the alert fires constantly, somebody switches it off, and the check
that would have caught the real expiry is gone. It can be run against a
fixture instead of a live Harbor:

```bash
ROBOTS_JSON="$(cat fixture.json)" ./expiring-robots.sh 14
```

which is how the CI tests it.

**The secret appears once.** There is no endpoint that returns it later.
Capture it at creation or refresh it — and read Chapter 19 before you
decide where to put it.
