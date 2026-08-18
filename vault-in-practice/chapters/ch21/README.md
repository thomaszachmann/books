# Chapter 21 — High Availability and Raft

**Starting state:** Docker running. This lab is self-contained and does
not touch your single-node lab.

**What this chapter builds:** a three-node Raft cluster, then breaks its
quorum on purpose and puts it back together.

```bash
./cluster-up.sh          # certs, configs, three nodes, initialised
./break-quorum.sh        # stop two nodes, watch Raft refuse
./cluster-down.sh
```

`break-quorum.sh` is the exercise that decides whether you can operate
this at three in the morning. Run it, read the error, and note what
recovery actually required — not restarting containers, but **unsealing**
them.
