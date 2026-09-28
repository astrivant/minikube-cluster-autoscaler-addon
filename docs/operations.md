# Operations

Run commands from the checkout or extracted archive. Set
`MINIKUBE_AUTOSCALER_PROFILE` when using a profile other than `minikube`.
The native bridge must be running while the provider is enabled.

## Status

```bash
bash scripts/addon.sh status
bash scripts/addon.sh test
```

`status` shows the provider journal, container status, and node pools. `test`
authenticates to the provider and checks the autoscaler rollout. Bridge logs
appear in its terminal; provider logs are available through
`docker logs minikube-cluster-autoscaler-addon-<profile>`.

## Scale-outs and scale-downs

The [HTTP load demo](demo.md) exercises the complete path from traffic to HPA
replicas to elastic workers. Run it with the commands in the
[README](../README.md#scale-outs-and-scale-downs).

Cluster Autoscaler acts on Pod requests and scheduling constraints. Worker size
comes from the captured Minikube profile. Default flags set a five-minute idle
window and one concurrent deletion. Local storage and system Pods affect
scale-down eligibility.

For a scheduling-only check, `examples/demand.yaml` creates a resource reservation
in the elastic pool without an HTTP workload.

## Disable and restart

```bash
bash scripts/addon.sh disable
# Stop the bridge with Ctrl-C.
```

Disable removes the Helm release and provider container. It retains nodes,
journals, credentials, base placement, the client TLS Secret, and the
ProvisioningRequest CRD. To restart, run `bridge` in one terminal and `enable`
in another.

## Recovery

An ownership or inventory mismatch pauses the provider and records `Error`
in `provider/state.json`. Inspect it with `status`, then stop both processes
before reconciling the reported node or configuration discrepancy.

```bash
bash scripts/addon.sh disable
# Stop the bridge and resolve the reported discrepancy.
bash scripts/addon.sh resume
bash scripts/addon.sh bridge
# In another terminal:
bash scripts/addon.sh enable
```

`resume` verifies the live inventory and bridge ownership before completing an
interrupted creation or clearing the error. Journals are bound to the original
cluster UID and initialization configuration. Cluster replacement or a change
of ownership scope requires retiring the previous elastic pool and initializing
with a fresh state directory. Run one autoscaler addon per cluster.
