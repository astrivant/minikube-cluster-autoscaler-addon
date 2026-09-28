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

Workloads use the elastic pool label and toleration defined in
[`examples/demand.yaml`](../examples/demand.yaml). Cluster Autoscaler scales from
Pod requests and scheduling constraints. Worker size comes from the captured
Minikube profile.

```bash
kubectl --context minikube apply -f examples/demand.yaml
kubectl --context minikube -n minikube-elastic-demo rollout status deployment/demand --timeout=16m
kubectl --context minikube get nodes -L minikube-autoscaler.astrivant.com/pool
kubectl --context minikube -n minikube-elastic-demo scale deployment/demand --replicas=0
```

Default chart flags set a five-minute idle window and one concurrent deletion.
Local storage and system Pods affect scale-down eligibility. The example
configuration allows two elastic workers alongside three 4 GiB base nodes,
within a 20 GiB node-memory ceiling.

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
