# Minikube integration

The built-in Minikube addon owns host setup and
process lifecycle. This repository supplies the provider, native bridge, Helm
chart, and platform lifecycle hooks (`scripts/addon.sh` on macOS/Linux and
`scripts/addon.ps1` on Windows).

## Installation

Use a Minikube build containing the [cluster-autoscaler integration](https://github.com/kubernetes/minikube/pull/23809).
The [README quick install](../README.md#quick-install) places this project at
`~/.minikube/addons/cluster-autoscaler`, where Minikube discovers it automatically.

For an existing checkout, an extracted [release bundle](releases.md#install-an-archive),
or a custom Minikube home, select the installation explicitly:

```bash
export MINIKUBE_AUTOSCALER_ADDON_PATH=/absolute/path/to/minikube-cluster-autoscaler-addon
minikube addons enable cluster-autoscaler
```

In PowerShell, set `$env:MINIKUBE_AUTOSCALER_ADDON_PATH` instead. Minikube also
finds a bundle through its binary on `PATH` and neighboring source checkouts
during development.

The host needs Docker, Helm and kubectl, plus Bash and jq on macOS/Linux or
PowerShell on Windows. Windows uses Docker Desktop with Linux containers.
Source checkouts also need
the Go version in `.go-version`. Start Docker and the cluster's driver services
before enabling the addon.

| Host | Architecture | Minikube driver |
| --- | --- | --- |
| macOS | arm64, amd64 | `qemu2` with `socket_vmnet` |
| macOS | arm64, amd64 | `vfkit` with `vmnet-shared` |
| Linux | amd64 | `kvm2` |
| Linux | arm64 | `docker` |
| Windows | amd64, arm64 | `docker` (Linux containers) |

Use Minikube's default stable Kubernetes release. The installed addon selects a
reviewed, digest-pinned Cluster Autoscaler image matching the actual server minor.
The current image catalog covers Kubernetes 1.35, 1.36 and 1.37; unknown minors or
prereleases fail before provider/controller mutation. For example,
create a one-node cluster on macOS and enable the addon:

```bash
minikube start --driver=qemu2 --network=socket_vmnet \
  --nodes=1 --cni=kindnet --memory=4096 --cpus=2
minikube addons enable cluster-autoscaler
```

On Intel and Apple Silicon Macs, `vfkit` can use the same provider with shared VM networking:

```bash
minikube start --driver=vfkit --network=vmnet-shared \
  --nodes=1 --cni=kindnet --memory=3072 --cpus=2
```

Install Minikube's vfkit networking prerequisites before running this command.
Select a cluster-wide CNI explicitly when starting from one node. A single-node
bridge-only default can leave an added worker NotReady because its CNI is not
initialized. `--cni=kindnet` supports the later worker fanout.

The addon continues to delegate worker creation/deletion to Minikube; it does not
invoke either hypervisor directly. Existing nodes remain protected base workers.
The `vmnet-host` network is rejected because this provider requires routable
multi-node and host-bridge connectivity. Intel macOS retains the QEMU path.

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
minikube start --driver=docker
minikube addons enable cluster-autoscaler
```

For direct diagnostics, use `./scripts/addon.ps1 -Action status` or `-Action test`.
The lifecycle hook supports Windows PowerShell 5.1 and PowerShell 7. Minikube
starts the bridge detached from the invoking console. Journal locking uses
Windows file locks; Docker Desktop forwards the mutually authenticated provider
connection to the host. Bash and jq are not required on Windows.
