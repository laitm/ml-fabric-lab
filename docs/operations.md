# Deploy & Operations

This page documents how to deploy, monitor, and destroy the labs using
`stage_deploy.sh`.

---

## Script Overview

`stage_deploy.sh` performs a **staged deployment**:

1. Deploys the **fabric lab**
2. Waits for EVPN BGP convergence
3. Deploys the **management lab**
4. Supports full teardown

---

## Usage

### Deploy (default)

```bash
./stage_deploy.sh
```

Equivalent to:

```bash
./stage_deploy.sh topology.fabric.yaml topology.mgmt.yaml
```

---

### Destroy both labs

```bash
./stage_deploy.sh destroy
```

Or explicitly:

```bash
./stage_deploy.sh destroy topology.fabric.yaml topology.mgmt.yaml
```

---

## What Happens During Deploy

### Stage 1 – Fabric
- Deploys `topology.fabric.yaml`
- Starts spines, leafs, and hosts
- No management containers are started yet

### EVPN Convergence Check
- Polls all spines and leafs
- Runs `show bgp evpn summary`
- Waits until **all neighbors are `Estab`**
- Displays a live progress bar
- Times out safely if convergence fails

### Stage 2 – Management
- Deploys `topology.mgmt.yaml`
- Starts telemetry, logging, and ntopng
- ntopng immediately begins sniffing fabric traffic

---

## Environment Variables

| Variable | Description | Default |
|-------|-------------|---------|
| `MAX_WAIT` | EVPN convergence timeout (seconds) | `300` |
| `POLL_INT` | Poll interval (seconds) | `10` |
| `SKIP_TAP_BRIDGE` | Skip bridge creation check | `0` |
| `NO_COLOR` | Disable ANSI colors | `0` |

Example:

```bash
MAX_WAIT=600 POLL_INT=15 ./stage_deploy.sh
```

---

## Common Operations

### Check container status
```bash
docker ps
```

### Check EVPN on a leaf
```bash
docker exec clab-arista-evpn-vxlan-fabric-leaf1   Cli -c "show bgp evpn summary"
```

### Restart management lab only
```bash
clab destroy -t topology.mgmt.yaml --cleanup
clab deploy -t topology.mgmt.yaml
```

---

## Failure Modes

### EVPN does not converge
- Check underlay reachability
- Verify EOS configs
- Script proceeds to management deploy after timeout

### ntopng sees no traffic
- Verify SPAN config on `leaf1`
- Confirm `br-fabric-tap` exists and is UP
- Confirm ntopng is capturing `eth1`

---

## Safety Notes

- `destroy` always removes **both labs**
- Docker volumes under `persist/` are preserved
- Host Linux bridge is **never deleted** by the script
