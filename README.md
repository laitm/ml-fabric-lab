# Arista EVPN/VXLAN Containerlab Lab
> **Split Fabric & Management Labs with Real Traffic Visibility**

This repository provides a **production-grade containerlab design** implementing an
**Arista EVPN/VXLAN fabric** with a **separate management / observability stack**.
The two labs are cleanly separated but interconnected using:
- a shared Docker management network (`clab-mgmt`)
- a shared Linux bridge tap (`br-fabric-tap`) for **real packet capture**

Designed and tested for **macOS + OrbStack + Docker + containerlab**.

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Topology Diagram](#topology-diagram)
- [Repository Structure](#repository-structure)
- [OrbStack Prerequisites](#orbstack-prerequisites)
- [Deployment Workflow](#deployment-workflow)
- [stage_deploy.sh](#stage_deploysh)
- [Observability Stack](#observability-stack)
- [EOS SPAN Configuration](#eos-span-configuration)
- [CI Linting](#ci-linting)
- [GitHub Pages](#github-pages)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Fabric Lab
- 2× Arista spines (eBGP underlay, EVPN route-servers)
- 4× Arista leafs (VXLAN VTEPs)
- 2× Linux hosts (iperf traffic generation)
- VLAN 10 stretched via EVPN
- Anycast gateway (VARP)
- SPAN mirror to tap interface

### Management Lab
- gnmic (gNMI telemetry)
- Prometheus (metrics)
- Grafana (dashboards)
- Alloy + Loki (logs)
- Redis
- ntopng (packet analysis)

### Shared Components
- Docker network: `clab-mgmt`
- Linux bridge: `br-fabric-tap` (host-based packet tap)

---

## Topology Diagram

```text
                    +---------+       +---------+
                    | spine1  |       | spine2  |
                    +----+----+       +----+----+
                         \                 //
                          \               //
                    +------+----+     +----+------+
                    |   leaf1   |     |   leaf4   |
                    | (VTEP)    |     | (VTEP)    |
                    +---+---+---+     +---+---+---+
                        |   |               |
                     host1   |            host2
                             |
                       SPAN → Eth5
                             |
                    br-fabric-tap (Linux bridge)
                             |
                         ntopng
```

---

## Repository Structure

```
.
├── topology.fabric.yaml
├── topology.mgmt.yaml
├── stage_deploy.sh
├── README.md
├── .github/workflows/lint.yml
├── .yamllint
├── configs/
│   ├── fabric/
│   ├── gnmic/
│   ├── prometheus/
│   ├── grafana/
│   ├── alloy/
│   └── loki/
└── persist/
```

---

## OrbStack Prerequisites

You must create a Linux bridge **inside OrbStack's Linux environment**.

```bash
orb create ubuntu clab
orb -m clab sudo ip link add br-fabric-tap type bridge
orb -m clab sudo ip link set br-fabric-tap up
```

Verify:

```bash
orb -m clab ip link show br-fabric-tap
```

> Docker bridge options (`com.docker.network.bridge.*`) are **not required**.

---

## Deployment Workflow

The lab is deployed in two stages:

1. Fabric lab
2. EVPN convergence check
3. Management lab

All handled by `stage_deploy.sh`.

---

## stage_deploy.sh

### Deploy
```bash
./stage_deploy.sh
```

### Destroy
```bash
./stage_deploy.sh destroy
```

### Environment Variables
| Variable | Description |
|--------|-------------|
| `MAX_WAIT` | EVPN convergence timeout |
| `POLL_INT` | Poll interval |
| `SKIP_TAP_BRIDGE=1` | Skip bridge creation |
| `NO_COLOR=1` | Disable ANSI output |

---

## Observability Stack

| Service | URL |
|------|-----|
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| ntopng | http://localhost:3001 |
| gnmic exporter | http://localhost:9804 |

Grafana default credentials: `admin / admin`

---

## EOS SPAN Configuration

Traffic will only reach ntopng if SPAN is configured on **leaf1**.

Example:

```eos
monitor session 1
  source interface Ethernet1
  source interface Ethernet2
  source interface Ethernet10
  destination interface Ethernet5
```

You may also mirror VLANs or Port-Channels.

---

## CI Linting

GitHub Actions automatically validates:
- YAML syntax (`yamllint`)
- Shell scripts (`shellcheck`)
- Trailing whitespace

Workflow: `.github/workflows/lint.yml`

---

## GitHub Pages

This repository is ready for **GitHub Pages**.

### Enable Pages
1. Repo → **Settings → Pages**
2. Source: `main` branch
3. Folder: `/docs`

### Files
```
docs/
└── index.md
```

The Pages site renders the same content as this README.

---

## Troubleshooting

**ntopng shows no traffic**
- Verify SPAN config on leaf1
- Confirm `br-fabric-tap` exists
- Ensure ntopng is capturing `eth1`

**EVPN never converges**
- Check EOS configs
- Validate underlay IP reachability

---

## License

MIT (or your preferred license)

---

Happy labbing 🚀
