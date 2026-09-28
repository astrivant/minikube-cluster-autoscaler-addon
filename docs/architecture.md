# Architecture and ownership

```text
Kubernetes Cluster Autoscaler
            |
     mutual TLS / externalgrpc
            |
Host provider container (Linux, readonly filesystem)
            |
     mutual TLS / bounded HTTP
            |
Native Go host bridge
            |
    scoped minikube + kubectl commands
            |
Protected base nodes + journal-owned elastic workers
```

The implementation and its tests live in `pkg/addon/`; generated upstream
protobufs live in `pkg/internal/protos/`. The root `main.go` passes release
metadata to the addon CLI.

`rpc.go` serves cached group state so VM startup never blocks gRPC deadlines.
`state.go` records desired workers before asynchronous provisioning begins.
`bridge.go` independently validates base-node identity, ownership and budget
outside the container's writable state. `backend.go` invokes native commands
and verifies drain/storage constraints before deletion. `tls.go` separates
autoscaler-client and bridge-client credentials. All infrastructure changes
are serialized and bounded by operation deadlines.

The provider container mounts only provider-owned state and its TLS identities.
The native bridge has the user's Minikube/kubectl access, not root by default.
Never grant the container Docker, kubeconfig, SSH or libvirt sockets.

Initialization protects the current cluster UID and base-node UIDs. It cannot
be repeated over existing ownership journals. New workers receive durable random
provider IDs; neither process adopts arbitrary nodes just because names match.
Deletion requires matching UID/provider ID, the autoscaler's cordon, no ordinary
Pods, no PVC-backed DaemonSets, and no local PV affinity to that worker. Minikube's
own deletion can force-drain, so these independent checks are necessary.

There is a short interval between Minikube node registration and applying elastic
labels/taints. Pinning infrastructure to base nodes protects it during that interval;
keep application placement explicit too. This is a local test tool, not a cloud
capacity guarantee or a production infrastructure controller.

Tests use fake provisioning, real gRPC/protobuf serialization, journal I/O,
timeouts and TLS listeners. CI runs race tests on the four supported host targets.
It cannot prove real hypervisor, firewall, PDB and volume behavior on every host.
The inherited macOS VM growth/shrink workflow was tested in Polyad; the standalone
Linux driver paths require live host validation before relying on them.
