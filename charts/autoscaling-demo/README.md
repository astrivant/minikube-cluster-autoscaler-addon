# Autoscaling demo

Runs a CPU workload, an HPA, and a k6 load generator to demonstrate scaling from one node to three.
See [running the demo](../../docs/demo.md).

## Parameters

### Traffic receiver

| Name                                 | Description                                      | Value                |
| ------------------------------------ | ------------------------------------------------ | -------------------- |
| `workload.image`                     | Traffic receiver image.                          | `python:3.13-alpine` |
| `workload.workMilliseconds`          | CPU work performed per request, in milliseconds. | `100`                |
| `workload.resources.requests.cpu`    | CPU request for the receiver.                    | `200m`               |
| `workload.resources.requests.memory` | Memory request for the receiver.                 | `64Mi`               |
| `workload.resources.limits.cpu`      | CPU limit for the receiver.                      | `500m`               |
| `workload.resources.limits.memory`   | Memory limit for the receiver.                   | `128Mi`              |

### Horizontal scaling

| Name                                 | Description                                                       | Value |
| ------------------------------------ | ----------------------------------------------------------------- | ----- |
| `hpa.minReplicas`                    | Minimum receiver replicas.                                        | `1`   |
| `hpa.maxReplicas`                    | Maximum receiver replicas; each replica requires a separate node. | `3`   |
| `hpa.targetCPUUtilizationPercentage` | CPU utilization target relative to each receiver CPU request.     | `50`  |
| `hpa.scaleDownStabilizationSeconds`  | HPA scale-down stabilization window in seconds.                   | `60`  |

### Load generator

| Name                                      | Description                                            | Value                         |
| ----------------------------------------- | ------------------------------------------------------ | ----------------------------- |
| `loadGenerator.enabled`                   | Run the load generator Job.                            | `true`                        |
| `loadGenerator.image`                     | k6 load generator image.                               | `grafana/k6:1.3.0`            |
| `loadGenerator.profile`                   | Load profile JSON file packaged under files/profiles/. | `files/profiles/default.json` |
| `loadGenerator.activeDeadlineSeconds`     | Maximum load generator Job duration in seconds.        | `3600`                        |
| `loadGenerator.resources.requests.cpu`    | CPU request for the load generator.                    | `100m`                        |
| `loadGenerator.resources.requests.memory` | Memory request for the load generator.                 | `64Mi`                        |
| `loadGenerator.resources.limits.cpu`      | CPU limit for the load generator.                      | `500m`                        |
| `loadGenerator.resources.limits.memory`   | Memory limit for the load generator.                   | `256Mi`                       |
