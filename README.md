# Minikube Cluster Autoscaler Addon

[![Go coverage](https://raw.githubusercontent.com/astrivant/minikube-cluster-autoscaler-addon/gh-pages/badges/coverage.svg)](https://github.com/astrivant/minikube-cluster-autoscaler-addon/actions/workflows/ci.yml)

Give local Kubernetes room to grow. Add workers when Pods need capacity and
remove idle workers when demand falls. Existing nodes stay in place.

This project supplies the host components for Minikube's `cluster-autoscaler`
addon. Minikube handles their setup and lifecycle.

## Contents

- [Quick install](#quick-install)
- [Scale-outs and scale-downs](#scale-outs-and-scale-downs)
- [Operations](#operations)
- [Development](#development)
- [Architecture](docs/architecture.md) and [configuration](docs/configuration.md)

## Quick install

Use a Minikube build containing [the addon integration](https://github.com/kubernetes/minikube/pull/23809)
and a running Kubernetes **1.35.x** cluster. Have Docker running, with Git,
Go **1.27.1**, Helm and kubectl installed; macOS/Linux also need Bash and jq,
and Windows uses PowerShell. [Host and cluster setup](docs/minikube-integration.md#installation)
covers supported drivers and cluster creation.

Install the host components once, then enable the addon:

```shell
git clone --depth 1 https://github.com/astrivant/minikube-cluster-autoscaler-addon.git "$HOME/.minikube/addons/cluster-autoscaler"
minikube addons enable cluster-autoscaler
```

Minikube discovers this installation, builds the components, configures resource
limits, starts the host bridge and provider, and installs Cluster Autoscaler.
The default allows up to **two additional workers**, within the host memory budget.

Check that the deployment is available:

```shell
kubectl --context minikube -n kube-system get deployment minikube-cluster-autoscaler-addon
```

The commands use the default `minikube` profile and home directory. For another
profile, add `-p <profile>` to Minikube commands and use the matching kubectl
context. [Custom installation paths](docs/minikube-integration.md#installation)
and [release bundles](docs/releases.md#install-an-archive) are covered separately.

## Scale-outs and scale-downs

Prove scaling with the included HTTP load demo. Start with one node, 2 CPUs and
4 GiB per node, and a host with at least 16 GiB of memory. For Docker nodes,
allocate at least 16 GiB to Docker as well. This gives the defaults room for
three 4 GiB nodes.

From the installed project directory:

```bash
cd "$HOME/.minikube/addons/cluster-autoscaler"
minikube addons enable metrics-server
kubectl --context minikube -n kube-system rollout status deployment/metrics-server --timeout=3m
helm upgrade --install scale-demo charts/autoscaling-demo \
  --kube-context minikube --namespace autoscaling-demo --create-namespace
kubectl --context minikube -n autoscaling-demo get hpa,pods -w
```

In another terminal, watch the cluster scale out:

```shell
kubectl --context minikube get nodes -L minikube-autoscaler.astrivant.com/pool -w
```

The load generator drives the HPA from one to three receiver Pods. Each receiver
needs its own node, so the two pending Pods trigger two new workers. Expect
**three Ready nodes and three Running receivers**. The default load lasts
41 minutes to allow for sequential worker creation.

Remove the demo to release the capacity:

```shell
helm uninstall scale-demo --kube-context minikube --namespace autoscaling-demo
```

Both elastic workers become eligible for removal after the five-minute idle
window. The original node remains. See the [demo guide](docs/demo.md) for
file-based load profiles, stopping traffic independently, and troubleshooting.

## Operations

```shell
minikube addons disable cluster-autoscaler
```

Disable stops autoscaling and its managed host processes, retaining nodes and
state. Re-enable with `minikube addons enable cluster-autoscaler`. See
[operations](docs/operations.md) for logs and recovery,
[configuration](docs/configuration.md) for limits, and
[architecture](docs/architecture.md) for components, state, and node ownership.

## Development

```bash
make build
make test
make vuln
make hooks
make lint
make chart
```

Go code lives in `pkg/addon/`; upstream protobufs live in `pkg/internal/protos/`.
The Dockerfile has `development` (source build) and `production` (release binary)
targets. See [contributing](CONTRIBUTING.md), [Minikube integration](docs/minikube-integration.md#local-development),
and [releases](docs/releases.md) for the development and release workflows.

Licensing: [GPL-3.0](LICENSE), [upstream notices](NOTICE),
[Apache-2.0](pkg/internal/protos/LICENSE).
