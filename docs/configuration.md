# Configuration reference

Minikube generates `<state-dir>/config.json` on first enable from the cluster
profile, host gateway, and available memory. For custom limits, place a complete
configuration there before first enable.

JSON is strict: unknown fields and trailing JSON objects are rejected.

| Field | Meaning and limits |
| --- | --- |
| `profile` | Existing Minikube profile and kubeconfig context; DNS label, at most 40 characters |
| `namespace` | Existing namespace for the autoscaler and TLS Secret; DNS label |
| `listen` | Specific unicast host IP and port `50051` |
| `minWorkers` | Minimum additional workers, zero or greater |
| `maxWorkers` | Maximum additional workers, 1-16 and at least `minWorkers` |
| `maxTotalMemoryMiB` | Hard ceiling for base plus maximum elastic node memory, at least 4096 MiB |
| `provisionTimeoutSeconds` | Native operation deadline, 60-3600 seconds |
| `cooldownSeconds` | Minimum interval between infrastructure changes, at least 10 seconds |

Worker sizing comes from the captured Minikube profile. The memory ceiling
covers base and elastic nodes; budget separately for host and Docker overhead.
Initialization requires agreement between the Minikube and Kubernetes inventories.
Configuration is bound to the journals; changes require retiring the existing
elastic pool and initializing a fresh state directory.

## Host examples

- macOS: `examples/config.macos.json`, gateway example `192.168.105.1`.
- Linux amd64 KVM: `examples/config.linux.json`, gateway example `192.168.39.1`.
- Linux arm64 Docker: `examples/config.linux-arm64.json`, gateway example `192.168.49.1`.

Verify addresses against the selected Minikube network. The provider container
reaches the bridge at `host.docker.internal:50052`; Docker Engine receives an
explicit host-gateway mapping. Nodes reach the provider at `listen`. Both links
use distinct mutual-TLS client identities. The bridge binds port 50052 on host
interfaces, so host firewall rules should restrict it to trusted local clients.

## Environment

Minikube accepts the addon path, state directory, binary, and image overrides
on first enable and saves them with the profile. It supplies the profile and
configuration path to script hooks. The configuration override is for direct
script use.

| Variable | Default |
| --- | --- |
| `MINIKUBE_AUTOSCALER_ADDON_PATH` | Auto-discovered bundle or neighboring checkout (Minikube integration) |
| `MINIKUBE_AUTOSCALER_PROFILE` | `minikube` |
| `MINIKUBE_AUTOSCALER_STATE_DIR` | `$XDG_STATE_HOME/minikube-cluster-autoscaler-addon/<profile>`, or `$HOME/.local/state/...` |
| `MINIKUBE_AUTOSCALER_CONFIG` | `<state-dir>/config.json`; point at an edited example for first initialization |
| `MINIKUBE_AUTOSCALER_BINARY` | `<project>/bin/minikube-cluster-autoscaler-addon` |
| `MINIKUBE_AUTOSCALER_IMAGE` | `minikube-cluster-autoscaler-addon:local` |
| `MINIKUBE_AUTOSCALER_BUILD_PROFILE` | `development` in source checkouts; `production` in release archives |

Use an absolute state path outside the checkout or release directory. The script
creates files with umask 077. One addon instance owns each cluster; use the
[lifecycle commands](operations.md) to manage its journals.

## Helm values

The wrapper chart is `charts/minikube-cluster-autoscaler-addon`. It uses upstream
Cluster Autoscaler chart 9.59.0 and image 1.35.0. `provider.address` is mandatory.
The chart uses the fixed release name `minikube-cluster-autoscaler-addon`
to match its ConfigMap and TLS Secret; the script supplies it consistently.
Values and their schema expose node placement, resource limits, TLS volumes,
upstream flags and worker provisioning timeout. Scale-down honors local-storage
and system-Pod exclusions, one deletion at a time.

The vendored ProvisioningRequest CRD is installed before Helm. It is outside
Helm's `crds/` directory so the script's field manager owns its installation.
Disabling retains this shared CRD and the client TLS Secret.
