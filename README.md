# Minikube Cluster Autoscaler Addon

[![Go coverage](https://raw.githubusercontent.com/astrivant/minikube-cluster-autoscaler-addon/gh-pages/badges/coverage.svg)](https://github.com/astrivant/minikube-cluster-autoscaler-addon/actions/workflows/ci.yml)

Add demand-driven worker scaling to Minikube. Kubernetes Cluster Autoscaler
runs in the cluster; a containerized Go provider delegates node operations to
a native host bridge. Existing nodes form a fixed base pool, and the addon
manages an elastic worker pool within configured resource limits.

Operate the addon through `scripts/addon.sh`.

## Contents

- [Quick install](#quick-install)
- [Activate on a cluster](#activate-on-a-cluster)
- [Scale-outs and scale-downs](#scale-outs-and-scale-downs)
- [Development](#development)
- [Architecture](docs/architecture.md), [configuration](docs/configuration.md),
  [operations](docs/operations.md), and [releases](docs/releases.md)

## Quick install

With Git, Go 1.27.1, Docker with BuildKit, Helm, kubectl, Minikube, and jq installed:

```bash
git clone https://github.com/astrivant/minikube-cluster-autoscaler-addon.git
cd minikube-cluster-autoscaler-addon
bash scripts/addon.sh build
```

This builds the native bridge and provider image. On macOS, `brew bundle`
installs the project tools; start Docker Desktop and `socket_vmnet` before
activating the addon. [Release archives](docs/releases.md#install-an-archive)
provide prebuilt binaries when a release is available.

## Activate on a cluster

Use Kubernetes **1.35.x** and one Ready control-plane node. Existing workers
join the fixed base pool. The chart pins Cluster Autoscaler **1.35.0** and
upstream chart **9.59.0**.

| Host | Architecture | Driver | Configuration |
| --- | --- | --- | --- |
| macOS | arm64, amd64 | `qemu2` with `socket_vmnet` | `examples/config.macos.json` |
| Linux | amd64 | `kvm2` | `examples/config.linux.json` |
| Linux | arm64 | `docker` (container nodes) | `examples/config.linux-arm64.json` |

For an existing compatible cluster, use its profile below. To create one on macOS:

```bash
minikube start -p minikube --driver=qemu2 --network=socket_vmnet \
  --kubernetes-version=v1.35.0 --nodes=1 --memory=4096 --cpus=2
```

On Linux, use the driver from the table and omit `--network`. Driver setup:
[QEMU](https://minikube.sigs.k8s.io/docs/drivers/qemu/),
[KVM2](https://minikube.sigs.k8s.io/docs/drivers/kvm2/).

Copy the configuration for your platform, set `profile` to the cluster name,
and set `listen` to the host IP reachable from its nodes, on port 50051.
Set the worker and memory limits for your host; see [configuration](docs/configuration.md).

```bash
cp examples/config.macos.json /tmp/minikube-autoscaler.json
# Edit /tmp/minikube-autoscaler.json for your cluster and host.
export MINIKUBE_AUTOSCALER_PROFILE=minikube
export MINIKUBE_AUTOSCALER_CONFIG=/tmp/minikube-autoscaler.json
bash scripts/addon.sh init
bash scripts/addon.sh bridge
```

`init` records the base pool and pins existing Deployments and StatefulSets in
`kube-system` and the configured namespace to it. The bridge stays running in
this terminal. In another terminal, from the project directory:

```bash
export MINIKUBE_AUTOSCALER_PROFILE=minikube
bash scripts/addon.sh enable
bash scripts/addon.sh test
bash scripts/addon.sh status
```

Subsequent commands use the configuration persisted by `init`.

## Scale-outs and scale-downs

Run the demo after activating the addon on a one-node cluster. Use the example
limits (`minWorkers: 0`, `maxWorkers: 2`) and at least 12 GiB of node-memory
budget for three 4 GiB nodes.

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

The Dockerfile has `development` (source build, default) and `production`
(prebuilt release binary) targets. `scripts/addon.sh build` selects the target
from the checkout or archive; override it with `MINIKUBE_AUTOSCALER_BUILD_PROFILE`.
Both targets share a non-root scratch runtime.

Licensing: [GPL-3.0](LICENSE), [upstream notices](NOTICE),
[Apache-2.0](pkg/internal/protos/LICENSE).
