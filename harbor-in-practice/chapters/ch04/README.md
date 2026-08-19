# Chapter 04 — Projects, Push, and Pull

**Starting state:** Chapter 3 finished. Harbor runs, `meridian` exists.

**What this chapter builds:** nothing permanent. It is about the two
APIs, what a project carries, and how a pull actually authenticates.

```bash
export HARBOR_URL=https://harbor.meridian.test
export HARBOR_USER=admin
read -rs HARBOR_PASS && export HARBOR_PASS

./create-project.sh platform auto_scan=true
./token-dance.sh platform/base 3.20
./list-all.sh /projects | jq -r '.[].name'
```

`token-dance.sh` does by hand what `docker pull` does by itself, and
prints the scope out of the token rather than describing it.

`jwt-decode.sh` exists because JWT segments are base64url and unpadded,
which `base64 -d` refuses. It is three lines and every one of them is
load-bearing.

`create-project.sh` reconciles rather than creates, so it is safe to run
twice — and it writes every metadata value as a string, because Harbor
accepts a JSON boolean, answers 201, and silently discards it.
