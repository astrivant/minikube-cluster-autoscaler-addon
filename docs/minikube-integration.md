# Minikube integration

The built-in addon in the neighboring Minikube project owns host setup and
process lifecycle. This repository supplies the provider, native bridge, Helm
chart, and platform lifecycle hooks (`scripts/addon.sh` on macOS/Linux and
`scripts/addon.ps1` on Windows).

## Installation

Use a Minikube build containing the `cluster-autoscaler` addon. Install this
project's [release bundle](releases.md#install-an-archive) under
`~/.minikube/addons/cluster-autoscaler`, or set
`MINIKUBE_AUTOSCALER_ADDON_PATH` to a checkout or extracted bundle.
Minikube also discovers a bundle through its binary on `PATH` and discovers
neighboring source checkouts during development.

The host needs Docker, Helm and kubectl, plus Bash and jq on macOS/Linux or
PowerShell on Windows. Windows uses Docker Desktop with Linux containers.
Source checkouts also need
the Go version in `.go-version`. Start Docker and the cluster's driver services
before enabling the addon.

| Host | Architecture | Minikube driver |
| --- | --- | --- |
| macOS | arm64, amd64 | `qemu2` with `socket_vmnet` |
| Linux | amd64 | `kvm2` |
| Linux | arm64 | `docker` |
| Windows | amd64, arm64 | `docker` (Linux containers) |

Use Kubernetes 1.35.x; the chart pins Cluster Autoscaler 1.35.0. For example,
create a one-node cluster on macOS and enable the addon:

```bash
minikube start --driver=qemu2 --network=socket_vmnet \
  --kubernetes-version=v1.35.0 --nodes=1 --memory=4096 --cpus=2
minikube addons enable cluster-autoscaler
```

On Linux and Windows, select the driver from the table and omit `--network`. Existing
workers become part of the fixed base pool.

## Lifecycle contract

Minikube resolves the bundle and persists its paths in the profile. On enable,
it builds missing host components, writes initial configuration, calls `init`,
starts the bridge, and calls `enable`. Subsequent enables reuse the journals
and configuration. It places a link to its own executable on the bridge's
`PATH`, so node operations use the same Minikube build.

Automatic configuration uses the profile's host gateway and node sizing. It
allows zero to two additional workers while reserving at least one quarter of
physical memory for the host. Docker nodes also respect the Docker daemon's
memory allocation. The resulting limits live in the profile's
[state directory](configuration.md#environment).

Minikube calls `disable` to remove the Helm release and provider container,
then stops the bridge it started. Cluster stop/delete also stops the host
components. Journals and credentials remain available for recovery.

| Interface | Owner |
| --- | --- |
| `minikube addons enable/disable cluster-autoscaler` | Minikube: discovery, defaults, locking, process startup and shutdown |
| `scripts/addon.sh build/init/enable/disable` | Addon: binaries/image, initialization, base placement, provider container, Helm release |
| Binary `--mode=bridge` | Native bridge process supervised by Minikube |
| Binary `--mode=bridge-check` / `maintenance-check` | Bridge authentication / journal lock checks |
| `scripts/addon.sh status/test/resume` | Operator diagnostics and recovery |

Minikube passes `MINIKUBE_AUTOSCALER_PROFILE`, `STATE_DIR`, `CONFIG`, `BINARY`,
and `IMAGE` (each with the `MINIKUBE_AUTOSCALER_` prefix) to script hooks.
`enable` expects initialized journals and a running bridge; `disable` leaves
bridge shutdown to Minikube.

## Local development

Keep `minikube` and `minikube-cluster-autoscaler-addon` side by side. From this
repository, use the neighboring Minikube build:

```bash
../minikube/out/minikube addons enable cluster-autoscaler
bash scripts/addon.sh test
```

For direct component debugging, initialize with an edited platform example and
run the bridge in the foreground:

```bash
bash scripts/addon.sh build
export MINIKUBE_AUTOSCALER_CONFIG=/absolute/path/to/config.json
bash scripts/addon.sh init
bash scripts/addon.sh bridge
# In another terminal, with the same profile and state directory:
bash scripts/addon.sh enable
```

Stop a manually launched bridge with Ctrl-C after `scripts/addon.sh disable`.

## Windows development

The Windows bundle includes `bin/minikube-cluster-autoscaler-addon.exe` and a
Linux provider binary for Docker Desktop. The Minikube command remains the same:

```powershell
minikube start --driver=docker --kubernetes-version=v1.35.0
minikube addons enable cluster-autoscaler
```

For direct diagnostics, use `./scripts/addon.ps1 -Action status` or `-Action test`.
The lifecycle hook supports Windows PowerShell 5.1 and PowerShell 7. Minikube
starts the bridge detached from the invoking console. Journal locking uses
Windows file locks; Docker Desktop forwards the mutually authenticated provider
connection to the host. Bash and jq are not required on Windows.
