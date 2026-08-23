# Chapter 5 — measured, and what is still open

Written while building the lab on 2026-08-23. Two findings are solid and
belong in the chapter. One piece of the lab does not work yet and is
recorded here rather than written up as if it did.

## 1. Rocky 10 needs x86-64-v3, and QEMU's default CPU does not provide it

Boot a Rocky 10 GenericCloud image under plain QEMU with no `-cpu`
argument and it panics:

```
[    9.259044] Kernel Offset: 0x8800000 from 0xffffffff81000000
[    9.259044] ---[ end Kernel panic - not syncing: Attempted to kill
               init! exitcode=0x00007f00 ]---
```

`exitcode=0x00007f00` is 127 shifted — *command not found*. init started
and exited immediately, which is what happens when userspace binaries
need instructions the CPU does not have.

RHEL 10, and therefore Rocky 10, requires **x86-64-v3**: AVX, AVX2,
BMI1, BMI2, FMA, MOVBE. QEMU's default `qemu64` model provides none of
them, no matter what the host CPU can do.

Measured on a host that has all six flags (Xeon E5-2620 v4):

| `-cpu` | Result |
|---|---|
| *(default `qemu64`)* | kernel panic, `Attempted to kill init!` |
| `host` | boots to `multi-user.target` |

The panic names nothing useful. Anyone hitting this will read
"Attempted to kill init" and start looking at the image.

**For the chapter:** the lab must pin `host-passthrough`, and the
substrate decision from Chapter 4 has a hardware consequence worth
stating — Rocky 10 excludes pre-Haswell hardware, which on-premises is
not a hypothetical.

## 2. An isolated libvirt network really is isolated, and it is checkable

`net-cluster.xml` has no `<forward/>` element. `net-mgmt.xml` has
`<forward mode='nat'/>`. The difference is visible in nftables:

```
$ sudo nft list table ip nat | grep -E '10.44|10.45'
ip saddr 10.45.0.0/24 ip daddr != 10.45.0.0/24 ip protocol tcp
    counter masquerade to :1024-65535
ip saddr 10.45.0.0/24 ip daddr != 10.45.0.0/24 ip protocol udp
    counter masquerade to :1024-65535
```

Two rules for `10.45.0.0/24`, **none at all** for `10.44.0.0/24`.

`lab.sh nets` asserts this rather than assuming it: if a masquerade rule
ever appears for the cluster network, it fails loudly. An isolated
network that quietly forwards would not be discovered until Chapter 27,
by which time several chapters would have been written against a lie.

## 3. Open: the VMs do not reach userspace under libvirt on this host

Under plain QEMU with `-cpu host`, the same overlay, the same seed ISO
and the same q35 machine type boot to `sysinit.target`. Under libvirt
they do not: no DHCP lease, no ARP on the bridge, silent serial console.

What was ruled out by measurement:

| Suspicion | Test | Result |
|---|---|---|
| Overlay larger than backing file | rebuilt at 10 G | still fails |
| UEFI-only image | partition table has BIOS boot **and** ESP | not it |
| q35 machine type | plain QEMU with `-machine q35` | boots |
| Seed CDROM on the q35 bus | plain QEMU with both drives | boots |
| No KVM acceleration | `domain type='kvm'`, `-cpu host,migratable=on` | not it |
| AppArmor confinement | `security_driver = "none"` | **partial** |

The AppArmor change moved the guest from 3 MB of writes to 23 MB — it
is booting further than before — but it still never obtains an address
and the console stays silent.

This is a property of the nested test host, not of the lab design. It is
recorded here so that the next person does not repeat the six
eliminations above.

**Not to do:** write the chapter as though `./lab.sh up` produces seven
reachable machines. It has not been shown to produce one.

**Next steps, in order of likely payoff:**

1. Run `lab.sh` on bare metal or a hypervisor host with unnested KVM,
   which is what the chapter targets anyway.
2. If it must work nested: compare the full QEMU command line libvirt
   generates against the one that boots, argument by argument. The log
   is at `/var/log/libvirt/qemu/<name>.log` and needs `sudo` to read.
3. Consider whether the lab should use plain QEMU with a bridge helper
   instead of libvirt. It has been shown to work here, and it removes a
   layer that this chapter does not otherwise need.
