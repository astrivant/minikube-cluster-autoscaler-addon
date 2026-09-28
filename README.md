# Minikube Cluster Autoscaler Addon

[![Pipeline](https://github.com/astrivant/minikube-cluster-autoscaler-addon/actions/workflows/ci.yml/badge.svg)](https://github.com/astrivant/minikube-cluster-autoscaler-addon/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/astrivant/minikube-cluster-autoscaler-addon?include_prereleases)](https://github.com/astrivant/minikube-cluster-autoscaler-addon/releases)

Scale a local Minikube cluster with upstream Kubernetes Cluster Autoscaler.
This standalone Go addon combines an `externalgrpc` provider in a restricted
host container with an authenticated native host bridge. Extracted from
[Polyad](https://github.com/astrivant/polyad), it has no Polyad runtime dependency.
It is an independent addon, not a built-in `minikube addons enable` plugin.

## Platforms

| Host | Architecture | Minikube driver |
| --- | --- | --- |
| macOS | arm64, amd64 | `qemu2`, QEMU/HVF and `socket_vmnet` |
| Linux | amd64 | `kvm2`, KVM/libvirt |
| Linux | arm64 | `docker`, explicit container-node fallback |

Windows and other architectures are unsupported. CI runs native Go tests on
all four host targets and builds four downloadable release archives.
Real VM provisioning is an explicit integration test, not part of unit CI.

**Linux arm64 is not VM-backed:** Minikube 1.39's KVM2 driver supports only amd64
([upstream source](https://github.com/kubernetes/minikube/blob/v1.39.0/pkg/minikube/registry/drvs/kvm2/kvm2.go)).
Docker-backed Minikube is accepted only on Linux arm64, not as a silent fallback
on VM-capable hosts. The addon pins Cluster Autoscaler **1.35.0**, Helm dependency
**9.59.0**, and requires Kubernetes **1.35.x** and one control-plane node.

## Install and activate

Install Docker, Helm, kubectl, Minikube and jq, plus the appropriate driver.
On macOS, `brew bundle` installs the listed tools. Starting Docker Desktop and
the privileged `socket_vmnet` service remains an explicit administrator step.
See [QEMU setup](https://minikube.sigs.k8s.io/docs/drivers/qemu/) or
[KVM2 setup](https://minikube.sigs.k8s.io/docs/drivers/kvm2/).

Download your matching archive and `checksums.txt` from
[Releases](https://github.com/astrivant/minikube-cluster-autoscaler-addon/releases).
Verify the archive's SHA-256 and extract it. Each archive includes the native
binary, a Linux provider binary, the chart and locked dependency, scripts,
examples, documentation and licenses. Release users do not need Go.

For example, on macOS arm64, replacing the version with an existing release:

```bash
VERSION=0.1.0
gh release download "v$VERSION" --repo astrivant/minikube-cluster-autoscaler-addon \
  --pattern "minikube-cluster-autoscaler-addon_${VERSION}_darwin_arm64.tar.gz" \
  --pattern checksums.txt
grep "minikube-cluster-autoscaler-addon_${VERSION}_darwin_arm64.tar.gz" checksums.txt | shasum -a 256 -c -
tar -xzf "minikube-cluster-autoscaler-addon_${VERSION}_darwin_arm64.tar.gz"
cd "minikube-cluster-autoscaler-addon_${VERSION}_darwin_arm64"
bin/minikube-cluster-autoscaler-addon --version
```

Start a separate profile, using the driver from the table above:

```bash
# macOS. Linux amd64: --driver=kvm2, without --network.
# Linux arm64: --driver=docker, without --network.
minikube start -p minikube --driver=qemu2 --network=socket_vmnet \
  --kubernetes-version=v1.35.0 --nodes=3 --memory=4096 --cpus=2
bash scripts/addon.sh build

# Review the relevant example and verify its reachable host IP first.
export MINIKUBE_AUTOSCALER_CONFIG="$PWD/examples/config.macos.json"
bash scripts/addon.sh init
bash scripts/addon.sh bridge
```

Keep the bridge running under your terminal or process supervisor. In another
terminal, from the same checkout or extracted release:

```bash
bash scripts/addon.sh enable
bash scripts/addon.sh test
bash scripts/addon.sh status
```

Initialization captures existing nodes as protected base nodes and pins current
Deployments/StatefulSets in the configured namespace and `kube-system` to them.
Use a dedicated cluster or review that placement change first. A custom
namespace must already exist. Defaults use `kube-system`.

The example addresses are not discovered: verify the host gateway on your
machine. Ports 50051 and 50052 require mutual TLS and should remain off
untrusted interfaces. The provider gets no Docker socket, kubeconfig, SSH keys,
Minikube disks or CA signing key. See [configuration](docs/configuration.md).

## Exercise growth and shrinkage

```bash
kubectl --context minikube create -f examples/demand.yaml
kubectl --context minikube -n minikube-elastic-demo rollout status deployment/demand --timeout=16m
kubectl --context minikube get nodes -L minikube-autoscaler.astrivant.com/pool
kubectl --context minikube -n minikube-elastic-demo scale deployment/demand --replicas=0
```

This reserves CPU/memory without busy-looping. Workloads must explicitly select
and tolerate the elastic pool. Requests and placement constraints, not current
CPU usage, drive node growth. Allow the configured five-minute idle window
before expecting shrinkage.

Examples allow two elastic workers beyond three 4 GiB base nodes: a 20 GiB
configured node-memory ceiling, excluding host and Docker overhead. For Linux
arm64 containers this is a sum of memory limits, not VM RAM reservations.

## Safety and recovery

The provider and bridge maintain independent ownership journals. Cluster UID
drift, unknown nodes, ambiguous provisioning and unsafe deletion pause the addon.
Deletion requires the autoscaler's cordon and completed PDB-aware eviction,
then independent identity and local-volume checks. Base nodes are never deleted.

```bash
bash scripts/addon.sh disable
# Stop the bridge with Ctrl-C. Repair the reported cause with both processes stopped.
bash scripts/addon.sh resume
bash scripts/addon.sh bridge
# Enable again from another terminal.
```

Disabling removes only the autoscaler release and host container. It retains
nodes, journals, credentials and base placement. It is not scale-to-zero.
Resolve elastic nodes before deleting/recreating a cluster; never reuse old
journals for a new cluster with the same name. Certificates last one year and
do not yet rotate automatically. Keep persistent application data off elastic
workers. See [architecture and ownership](docs/architecture.md).

Do not run this addon and Polyad's original addon against the same profile.
Their labels, journals and releases are separate. This extraction does not
migrate or modify the existing Polyad lab.

## Development and releases

The single Dockerfile provides two build profiles through named targets:

- `development` compiles the provider from source (the default Docker target).
- `production` packages the prebuilt `bin/provider-linux` supplied in release archives.

Both profiles use the same restricted scratch runtime. `scripts/addon.sh build`
selects development in source checkouts and production in extracted releases.
Override the selection with `MINIKUBE_AUTOSCALER_BUILD_PROFILE`, independently
of the Minikube cluster profile:

```bash
MINIKUBE_AUTOSCALER_BUILD_PROFILE=development bash scripts/addon.sh build
# From an extracted release archive:
MINIKUBE_AUTOSCALER_BUILD_PROFILE=production bash scripts/addon.sh build
```

For container-only builds:

```bash
docker build --target development -t minikube-cluster-autoscaler-addon:local .
# With the prebuilt Linux binary present:
docker build --target production -t minikube-cluster-autoscaler-addon:local .
```

These targets require Docker BuildKit so production builds can skip the source
compilation stage.

Use Go 1.27.1, pre-commit, ShellCheck, shfmt, actionlint and Helm:

```bash
make build
make test
make hooks
make lint
make chart
```

One [CI entry workflow](.github/workflows/ci.yml) calls separate test, build and
release stages. Branch pushes, PRs and manual runs validate the project.
A pushed version tag publishes only after every required check passes:

```bash
git tag -a v0.1.0 -m 'Release v0.1.0'
git push origin v0.1.0
```

The release includes generated notes, four platform archives and SHA-256 checksums.
Tags such as `v0.1.0-alpha.1` create prereleases without changing latest stable.
Publishing uses the scoped `GITHUB_TOKEN`; no publication PAT is required.
Binaries are not Apple-notarized. Checksums detect corruption, not independent
publisher identity. See [release maintenance](docs/releases.md).

Original GPL-3.0 licensing and upstream Apache-2.0 notices are retained in
[LICENSE](LICENSE), [NOTICE](NOTICE), and [LICENSE.kubernetes](LICENSE.kubernetes).
