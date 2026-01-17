# Troubleshooting

This page covers common issues encountered when deploying or operating the lab.

---

## ntopng Shows No Traffic

### Symptoms
- ntopng UI loads but shows zero flows
- Interfaces appear up, but no packets are seen

### Checks
1. Verify SPAN configuration on `leaf1`:
   ```eos
   show monitor
   ```
2. Ensure `Ethernet5` is the SPAN destination
3. Confirm the tap bridge exists:
   ```bash
   orb -m clab ip link show br-fabric-tap
   ```
4. Confirm ntopng is capturing `eth1`
5. Verify link exists in both labs:
   - `leaf1:eth5` → `br-fabric-tap`
   - `ntopng:eth1` → `br-fabric-tap`

---

## EVPN Does Not Converge

### Symptoms
- Deploy script stalls at EVPN wait stage
- `show bgp evpn summary` shows neighbors not established

### Checks
```bash
show ip bgp summary
show bgp evpn summary
show interfaces status
```

### Notes
- The deploy script will time out safely
- Management lab will still deploy after timeout

---

## Containers Fail to Start

### Checks
```bash
docker ps -a
docker logs <container>
```

- Ensure `clab-mgmt` network exists
- Ensure required images are pulled

---

## Bridge Errors

### Symptoms
- containerlab errors referencing `kind: bridge`
- ntopng tap interface missing

### Resolution
Ensure the bridge exists **before** deployment:

```bash
orb -m clab sudo ip link add br-fabric-tap type bridge
orb -m clab sudo ip link set br-fabric-tap up
```

---

## Cleanup Issues

### Symptoms
- Containers remain after destroy
- Volumes persist unexpectedly

### Resolution
```bash
clab destroy -t topology.fabric.yaml --cleanup
clab destroy -t topology.mgmt.yaml --cleanup
```

Persistent data under `persist/` is intentionally preserved.

---

## Getting Help

If something still doesn’t look right:
- Enable verbose output in the deploy script
- Inspect EOS configs under `configs/fabric/`
- Use `docker exec` to inspect containers interactively
