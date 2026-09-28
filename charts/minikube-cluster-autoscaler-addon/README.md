# Minikube Cluster Autoscaler

Runs Cluster Autoscaler with the external gRPC provider configured by the Minikube addon.
See [installation](../../README.md#quick-install) and [configuration](../../docs/configuration.md).

## Parameters

### Provider connection

| Name               | Description                                    | Value |
| ------------------ | ---------------------------------------------- | ----- |
| `provider.address` | Host-published provider address and gRPC port. | `""`  |

### Cluster Autoscaler

| Name                                                                     | Description                                                            | Value                                        |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------- | -------------------------------------------- |
| `cluster-autoscaler.fullnameOverride`                                    | Name used for Cluster Autoscaler resources.                            | `minikube-cluster-autoscaler-addon`          |
| `cluster-autoscaler.cloudProvider`                                       | Cluster Autoscaler provider; this addon uses externalgrpc.             | `externalgrpc`                               |
| `cluster-autoscaler.autoDiscovery.clusterName`                           | Minikube profile name.                                                 | `minikube`                                   |
| `cluster-autoscaler.image.tag`                                           | Cluster Autoscaler image tag, matched to the Kubernetes minor version. | `v1.35.0`                                    |
| `cluster-autoscaler.replicaCount`                                        | Number of Cluster Autoscaler replicas.                                 | `1`                                          |
| `cluster-autoscaler.nodeSelector.minikube-autoscaler.astrivant.com/pool` | Node pool hosting Cluster Autoscaler.                                  | `base`                                       |
| `cluster-autoscaler.extraArgs.cloud-config`                              | Path to the mounted external gRPC provider configuration.              | `/etc/provider/cloud-config.yaml`            |
| `cluster-autoscaler.extraArgs.max-node-provision-time`                   | Maximum time allowed for a new worker to become ready.                 | `16m`                                        |
| `cluster-autoscaler.extraArgs.scale-down-delay-after-add`                | Delay before considering scale down after adding a node.               | `5m`                                         |
| `cluster-autoscaler.extraArgs.scale-down-unneeded-time`                  | Time a node must remain unneeded before removal.                       | `5m`                                         |
| `cluster-autoscaler.extraArgs.scale-down-unready-time`                   | Time an unready node must remain unneeded before removal.              | `10m`                                        |
| `cluster-autoscaler.extraArgs.max-scale-down-parallelism`                | Maximum concurrent node removals.                                      | `1`                                          |
| `cluster-autoscaler.extraArgs.max-nodes-per-scaleup`                     | Maximum nodes added in one scale-out decision.                         | `1`                                          |
| `cluster-autoscaler.extraArgs.enable-provisioning-requests`              | Enable ProvisioningRequest processing.                                 | `true`                                       |
| `cluster-autoscaler.extraArgs.skip-nodes-with-local-storage`             | Keep nodes with pods using local storage.                              | `true`                                       |
| `cluster-autoscaler.extraArgs.skip-nodes-with-system-pods`               | Keep nodes with non-DaemonSet system pods.                             | `true`                                       |
| `cluster-autoscaler.extraArgs.leader-elect`                              | Enable leader election among autoscaler replicas.                      | `true`                                       |
| `cluster-autoscaler.extraArgs.v`                                         | Cluster Autoscaler log verbosity.                                      | `4`                                          |
| `cluster-autoscaler.extraVolumes[0].name`                                | Provider configuration volume name.                                    | `provider-config`                            |
| `cluster-autoscaler.extraVolumes[0].configMap.name`                      | Provider configuration ConfigMap name.                                 | `minikube-cluster-autoscaler-addon-provider` |
| `cluster-autoscaler.extraVolumes[1].name`                                | Client TLS volume name.                                                | `provider-client`                            |
| `cluster-autoscaler.extraVolumes[1].secret.secretName`                   | Client TLS Secret name.                                                | `minikube-cluster-autoscaler-addon-client`   |
| `cluster-autoscaler.extraVolumeMounts[0].name`                           | Mounted volume name.                                                   | `provider-config`                            |
| `cluster-autoscaler.extraVolumeMounts[0].mountPath`                      | Container mount path.                                                  | `/etc/provider`                              |
| `cluster-autoscaler.extraVolumeMounts[0].readOnly`                       | Mount the volume read-only.                                            | `true`                                       |
| `cluster-autoscaler.extraVolumeMounts[1].name`                           | Mounted volume name.                                                   | `provider-client`                            |
| `cluster-autoscaler.extraVolumeMounts[1].mountPath`                      | Container mount path.                                                  | `/etc/provider-tls`                          |
| `cluster-autoscaler.extraVolumeMounts[1].readOnly`                       | Mount the volume read-only.                                            | `true`                                       |
| `cluster-autoscaler.resources.requests.cpu`                              | CPU reserved for Cluster Autoscaler.                                   | `100m`                                       |
| `cluster-autoscaler.resources.requests.memory`                           | Memory reserved for Cluster Autoscaler.                                | `128Mi`                                      |
| `cluster-autoscaler.resources.limits.cpu`                                | CPU limit for Cluster Autoscaler.                                      | `500m`                                       |
| `cluster-autoscaler.resources.limits.memory`                             | Memory limit for Cluster Autoscaler.                                   | `512Mi`                                      |
