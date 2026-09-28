# Architecture

```text
Cluster Autoscaler (in-cluster)
    │ externalgrpc / mutual TLS / host port 50051
    ▼
Go provider (Docker container)
    │ HTTP / mutual TLS / host port 50052
    ▼
Go bridge (native host process)
    │ minikube + kubectl
    ▼
Base nodes + elastic workers
```

## Components

Minikube owns addon discovery, initial configuration, and host process lifecycle.
Its built-in addon invokes this repository’s script hooks to build components,
initialize state, and install or remove the Helm release. See the
[integration contract](minikube-integration.md#lifecycle-contract).

Cluster Autoscaler makes scheduling and scale-down decisions. The provider
exposes one worker group, `minikube-workers`, and persists requested capacity
before reconciling it asynchronously. The native bridge executes node operations
with the host's Minikube and kubectl access. This lets the same Linux provider
image work with macOS QEMU and Linux drivers.

The provider mounts its journal and TLS identities. It runs with a read-only
root filesystem, dropped capabilities, and bounded CPU, memory, and process
counts. The bridge holds a separate journal and checks each request against the
cluster inventory, worker ownership, and resource budget.

## Scaling and ownership

Initialization captures the cluster UID, node UIDs, Minikube sizing, and existing
nodes as the base pool. With one node, the worker template uses observed
control-plane capacity; with existing workers, it prefers a worker. The template
strips node identity, role labels, and taints before advertising elastic capacity.
The base pool remains fixed for that initialization.
Elastic workers receive unique provider IDs and move through `queued`,
`creating`, `ready`, and `deleting` states. Reconciliation runs every five seconds;
mutations are serialized and respect the configured cooldown and deadline.

Scale-out records intent before creating a worker. The bridge records ownership,
waits for readiness, and applies the elastic labels and taint. Existing
infrastructure controllers are pinned to base nodes during initialization so
new workers can register before their placement metadata is applied.

For scale-down, Cluster Autoscaler cordons the worker and completes PDB-aware
Pod eviction. Before deletion, the bridge verifies UID and provider ID, completed
Pod termination, DaemonSet storage, and persistent-volume affinity. These checks
precede Minikube's node-delete operation, which can force-drain internally.

Inventory drift or an interrupted operation records a provider error and pauses
reconciliation. Recovery reconciles both journals with observed infrastructure;
see [operations](operations.md#recovery).

## State and authentication

The state directory is scoped to a Minikube profile:

| Path | Purpose |
| --- | --- |
| `config.json` | Persisted initialization configuration |
| `bridge.log`, `bridge.pid`, `minikube.lock` | Minikube-managed bridge logs, process identity, and lifecycle lock |
| `provider/state.json` | Desired capacity, worker phases, base inventory, and current error |
| `provider/config.json`, `provider/tls/` | Container configuration and TLS identities |
| `host/bridge.json`, `host/tls/` | Native bridge ownership journal and TLS identities |
| `client/tls/` | Autoscaler client identity copied into a Kubernetes Secret |

File locks enforce one lifecycle owner per journal. Writes use atomic replacement.
Each link uses a distinct mutual-TLS client role: autoscaler to provider, provider
to bridge. Certificates have a one-year lifetime and rotation is manual.

## Code map

The root `main.go` passes release metadata into `pkg/addon.Execute`.

| File in `pkg/addon/` | Responsibility |
| --- | --- |
| `addon.go` | CLI modes, initialization, servers, and reconciliation loop |
| `config.go` | Configuration and platform validation |
| `rpc.go` | Cluster Autoscaler gRPC methods and cached group state |
| `state.go` | Provider journal, worker transitions, and reconciliation |
| `bridge.go` | Authenticated host API and independent ownership checks |
| `backend.go` | Minikube/kubectl operations and inventory/deletion checks |
| `tls.go` | Certificate issuance and role-specific TLS configuration |

`pkg/internal/protos/` contains the upstream externalgrpc protocol.
Tests combine a fake provisioning backend with real gRPC serialization, journal
I/O, and TLS listeners. CI runs race tests on all four host targets; the
[scale-out procedure](operations.md#scale-outs-and-scale-downs) exercises the host driver.
