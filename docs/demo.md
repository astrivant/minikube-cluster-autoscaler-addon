# HTTP autoscaling demo

The `charts/autoscaling-demo` chart exercises this chain:

```text
k6 → Service → CPU-bound receiver → metrics-server → HPA
                                                   ↓
                                          pending receiver Pods
                                                   ↓
                                        Cluster Autoscaler → addon
                                                   ↓
                                            two new workers
```

## Starting configuration

Start with one Ready Minikube node, Kubernetes 1.35.x, and the addon enabled.
Use 2 CPUs and 4 GiB per node, `minWorkers: 0`, `maxWorkers: 2`, and
`maxTotalMemoryMiB` of at least 12288. Reserve additional host memory for Docker
and local applications. Enable the Minikube `metrics-server` addon before
installing the chart. Commands are in the [README](../README.md#scale-outs-and-scale-downs).

The default receiver requests 200m CPU and has a 500m limit. Each `/work` request
consumes 100 ms of CPU time. The HPA targets 50% of the CPU request and manages
one to three replicas. Twelve concurrent k6 users keep receivers above that target.

Required Pod anti-affinity permits one receiver per hostname. With a single base
node, replicas two and three need two elastic workers. This placement makes the
node count independent of spare CPU capacity on the base node. Receiver Pods
tolerate the elastic taint and can use either pool; the load generator stays on
the base pool. Other workloads and existing base nodes change this arrangement.

The Job ramps to twelve users over 30 seconds, holds for 40 minutes, and ramps
down over 30 seconds. Its one-hour deadline bounds the run. It sends requests
through the Service with connection reuse disabled, distributing traffic as
receivers become available.

## Observe

```bash
kubectl --context minikube -n autoscaling-demo get hpa,pods -w
kubectl --context minikube get nodes -L minikube-autoscaler.astrivant.com/pool -w
kubectl --context minikube -n autoscaling-demo top pods
kubectl --context minikube -n autoscaling-demo logs -f job/scale-demo-demo-load
```

Look for CPU above the HPA target, a desired replica count of three, pending
receivers, then two new Ready nodes and three Running receivers. Node provisioning
is sequential and can take several minutes per worker.

| Observation | Inspect |
| --- | --- |
| HPA CPU shows `<unknown>` | `kubectl --context minikube top nodes`; metrics-server rollout and logs |
| Receiver is Pending | `kubectl describe pod` in `autoscaling-demo`; pool labels, anti-affinity, and node resources |
| HPA stays at one | Load Job logs and completion status; receiver CPU metrics |
| Workers are not added | Autoscaler logs in `kube-system`; `scripts/addon.sh status` and bridge logs |

## Load profiles

Profiles are k6 options JSON files packaged with the chart. Add, for example,
`charts/autoscaling-demo/files/profiles/short.json`:

```json
{
  "stages": [
    {"duration": "30s", "target": 12},
    {"duration": "10m", "target": 12},
    {"duration": "30s", "target": 0}
  ],
  "noConnectionReuse": true,
  "discardResponseBodies": true
}
```

Select it when installing:

```bash
helm upgrade --install scale-demo charts/autoscaling-demo \
  --kube-context minikube --namespace autoscaling-demo --create-namespace \
  --set loadGenerator.profile=files/profiles/short.json
```

The selected file is mounted as `/demo/profile.json`. The chart rejects missing
files and invalid JSON. The load script reads the file at startup; delete the
existing Job before an upgrade to rerun with a new profile:

```bash
kubectl --context minikube -n autoscaling-demo delete job scale-demo-demo-load
# Rerun the Helm command with the selected profile.
```

Use `loadGenerator.activeDeadlineSeconds` for profiles longer than an hour.
Receiver work per request is configurable through `workload.workMilliseconds`.
The chart's [values](../charts/autoscaling-demo/values.yaml) expose resource
requests, limits, images, and HPA settings.

## Scale-down and cleanup

Stop traffic while keeping the receivers installed:

```bash
helm upgrade scale-demo charts/autoscaling-demo --kube-context minikube \
  --namespace autoscaling-demo --reuse-values --set loadGenerator.enabled=false
```

The HPA returns to one replica after its 60-second stabilization window.
That remaining Pod can occupy an elastic node. Uninstalling the demo removes
all receivers so both elastic workers can drain and be deleted after the
five-minute autoscaler idle window. The base node remains.

For local chart checks, run `make demo-test` with Helm, Python, and PyYAML
(installed with pre-commit). CI runs these checks alongside Helm lint.

References: [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/),
[k6 options](https://grafana.com/docs/k6/latest/using-k6/k6-options/reference/).
