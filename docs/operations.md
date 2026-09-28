# Operations

Use `minikube addons enable/disable cluster-autoscaler` to manage the addon.
Add `-p <profile>` for another cluster. Run diagnostic scripts from the checkout
or extracted bundle, setting `MINIKUBE_AUTOSCALER_PROFILE` to the same profile
and `MINIKUBE_AUTOSCALER_STATE_DIR` if using a custom state path.

## Status

```bash
bash scripts/addon.sh status
bash scripts/addon.sh test
```

`status` shows the provider journal, container status, and node pools. `test`
authenticates to the provider and checks the autoscaler rollout. Minikube writes bridge logs
to `<state-dir>/bridge.log`; provider logs are available through
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
minikube addons disable cluster-autoscaler
```

Disable removes the Helm release and provider container and stops the managed bridge. It retains nodes,
journals, credentials, base placement, the client TLS Secret, and the
ProvisioningRequest CRD. To restart, run `minikube addons enable cluster-autoscaler`.

## Recovery

An ownership or inventory mismatch pauses the provider and records `Error`
in `provider/state.json`. Inspect it with `status`, then stop both processes
before reconciling the reported node or configuration discrepancy.

```bash
minikube addons disable cluster-autoscaler
# Resolve the reported discrepancy.
bash scripts/addon.sh resume
minikube addons enable cluster-autoscaler
```

`resume` verifies the live inventory and bridge ownership before completing an
interrupted creation or clearing the error. Journals are bound to the original
cluster UID and initialization configuration. Cluster replacement or a change
of ownership scope requires retiring the previous elastic pool and initializing
with a fresh state directory. Run one autoscaler addon per cluster.
