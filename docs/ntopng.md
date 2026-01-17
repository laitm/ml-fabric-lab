# ntopng Usage

This page explains how ntopng is used in this lab to analyze **real mirrored fabric traffic**.

---

## Interface Model

In this design:

| Interface | Purpose |
|--------|---------|
| `eth0` | Management (`clab-mgmt`) |
| `eth1` | Tap (`br-fabric-tap`) |

ntopng is started with:

```bash
ntopng --community --redis redis -i eth1 --disable-autologout
