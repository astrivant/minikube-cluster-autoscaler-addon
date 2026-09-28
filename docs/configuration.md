# Configuration reference

JSON is strict: unknown fields and trailing JSON objects are rejected.

| Field | Meaning and limits |
| --- | --- |
| `profile` | Existing Minikube profile and kubeconfig context; DNS label, at most 40 characters |
| `namespace` | Existing namespace for the autoscaler and TLS Secret; DNS label |
| `listen` | Explicit host IP and port `50051`; never a wildcard or multicast IP |
| `minWorkers` | Minimum additional workers, zero or greater |
| `maxWorkers` | Maximum additional workers, 1-16 and at least `minWorkers` |
| `maxTotalMemoryMiB` | Hard ceiling for base plus maximum elastic node memory, at least 4096 MiB |
| `provisionTimeoutSeconds` | Native operation deadline, 60-3600 seconds |
| `cooldownSeconds` | Minimum interval between infrastructure changes, at least 10 seconds |

Worker sizing comes from the captured Minikube profile, not Pod requests.
The memory ceiling excludes host OS, Docker and other applications. All initial
nodes must match the profile and Kubernetes inventory. Configuration changes
after initialization are rejected rather than silently changing ownership scope.
Drain workers and explicitly retire the old configuration before reinitializing.

## Host examples

- macOS: `examples/config.macos.json`, gateway example `192.168.105.1`.
- Linux amd64 KVM: `examples/config.linux.json`, gateway example `192.168.39.1`.
- Linux arm64 Docker: `examples/config.linux-arm64.json`, gateway example `192.168.49.1`.

Verify addresses against the selected Minikube network. The provider container
reaches the bridge at `host.docker.internal:50052`; Docker Engine receives an
explicit host-gateway mapping. Nodes reach the provider at `listen`. Both links
use distinct mutual-TLS client identities. The bridge binds port 50052 on host
interfaces, so host firewall rules should restrict it to trusted local clients.

## Script environment

| Variable | Default |
| --- | --- |
| `MINIKUBE_AUTOSCALER_PROFILE` | `minikube` |
| `MINIKUBE_AUTOSCALER_STATE_DIR` | `$XDG_STATE_HOME/minikube-cluster-autoscaler-addon/<profile>`, or `$HOME/.local/state/...` |
| `MINIKUBE_AUTOSCALER_CONFIG` | `<state-dir>/config.json`; point at an edited example for first initialization |
| `MINIKUBE_AUTOSCALER_BINARY` | `<project>/bin/minikube-cluster-autoscaler-addon` |
| `MINIKUBE_AUTOSCALER_IMAGE` | `minikube-cluster-autoscaler-addon:local` |

The state directory must be absolute and private. Never commit journals,
credentials, kubeconfigs or VM data. The script creates files with umask 077.
Leave state outside release directories so upgrading binaries does not discard it.
Do not edit journals manually or operate multiple add-ons against one cluster.

## Helm values

The wrapper chart is `charts/minikube-cluster-autoscaler-addon`. It uses upstream
Cluster Autoscaler chart 9.59.0 and image 1.35.0. `provider.address` is mandatory.
The chart intentionally uses the fixed release name `minikube-cluster-autoscaler-addon`
to match its ConfigMap and TLS Secret; the script supplies it consistently.
Values and their schema expose node placement, resource limits, TLS volumes,
upstream flags and worker provisioning timeout. Scale-down honors local-storage
and system-Pod exclusions, one deletion at a time.

The vendored ProvisioningRequest CRD is installed before Helm. It is outside
Helm's `crds/` directory so the script's field manager owns its installation.
Disabling retains this shared CRD and the client TLS Secret.
