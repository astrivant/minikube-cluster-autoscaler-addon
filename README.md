# Minikube Cluster Autoscaler Addon

[![Go coverage](https://raw.githubusercontent.com/astrivant/minikube-cluster-autoscaler-addon/gh-pages/badges/coverage.svg)](https://github.com/astrivant/minikube-cluster-autoscaler-addon/actions/workflows/ci.yml)

Add demand-driven worker scaling to Minikube. Kubernetes Cluster Autoscaler
runs in the cluster; a containerized Go provider delegates node operations to
a native host bridge. Existing nodes form a fixed base pool, and the addon
manages an elastic worker pool within configured resource limits.

## Contents

- [Quick install](#quick-install)
- [Scale-outs and scale-downs](#scale-outs-and-scale-downs)
- [Development](#development)
- [Architecture](docs/architecture.md), [configuration](docs/configuration.md),
  [operations](docs/operations.md), and [releases](docs/releases.md)

## Quick install

Enable the addon on a running cluster:

```bash
minikube addons enable cluster-autoscaler
```

Minikube prepares the provider, generates configuration, starts the host bridge,
and installs Cluster Autoscaler. Existing nodes stay in the base pool; the addon
adds up to two workers as workloads need capacity, within the host memory budget.
Use `-p <profile>` to select another cluster.

Use the Minikube build with the built-in `cluster-autoscaler` integration and
this project's addon bundle. During development, the neighboring `../minikube`
checkout discovers this repository automatically. See [installation and
integration](docs/minikube-integration.md) for bundle placement and host requirements.

## Scale-outs and scale-downs

Run the demo from this checkout or an extracted addon bundle on a one-node
cluster. Three 4 GiB nodes need a 12 GiB node-memory budget; the automatic
defaults allow this on a host with at least 16 GiB of memory.

```bash
minikube -p minikube addons enable metrics-server
kubectl --context minikube -n kube-system rollout status deployment/metrics-server --timeout=3m
helm upgrade --install scale-demo charts/autoscaling-demo \
  --kube-context minikube --namespace autoscaling-demo --create-namespace
kubectl --context minikube -n autoscaling-demo get hpa,pods -w
# In another terminal:
kubectl --context minikube get nodes -L minikube-autoscaler.astrivant.com/pool -w
```

The k6 Job sends HTTP traffic to a CPU-bound receiver. Its HPA scales from one
to three replicas at 50% CPU utilization. Required Pod anti-affinity places one
receiver per node, so the two pending replicas trigger two elastic workers.
Expect **three Ready nodes and three Running receiver Pods** once provisioning
completes. The default load lasts 41 minutes to cover sequential node creation.

Add a k6 options JSON file under `charts/autoscaling-demo/files/profiles/` and
select it with `--set loadGenerator.profile=files/profiles/my-profile.json`.
See the [demo guide](docs/demo.md) for profiles, observations, and troubleshooting.

Stop the load and watch the HPA return to one replica:

```bash
helm upgrade scale-demo charts/autoscaling-demo --kube-context minikube \
  --namespace autoscaling-demo --reuse-values --set loadGenerator.enabled=false
```

To remove the demo and let both elastic nodes scale down:

```bash
helm uninstall scale-demo --kube-context minikube --namespace autoscaling-demo
```

The autoscaler's idle window is five minutes. [Operations](docs/operations.md)
covers addon shutdown and recovery.

## Development

```bash
make build
make test
make hooks
make lint
make chart
```

Go implementation and tests live in `pkg/addon/`; upstream protobufs live in
`pkg/internal/protos/`. See [architecture](docs/architecture.md) for the code map
and [contributing](CONTRIBUTING.md) for validation conventions.
[Minikube integration](docs/minikube-integration.md) covers local builds and
the host component interface.

The Dockerfile has `development` (source build, default) and `production`
(prebuilt release binary) targets. `scripts/addon.sh build` selects the target
from the checkout or archive; override it with `MINIKUBE_AUTOSCALER_BUILD_PROFILE`.
Both targets share a non-root scratch runtime.

Licensing: [GPL-3.0](LICENSE), [upstream notices](NOTICE),
[Apache-2.0](pkg/internal/protos/LICENSE).
