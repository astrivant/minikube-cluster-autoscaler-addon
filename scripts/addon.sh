#!/usr/bin/env bash
# Repository-local Minikube Helm addon, with a containerized host provider.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PROFILE="${MINIKUBE_AUTOSCALER_PROFILE:-minikube}"
STATE_DIR="${MINIKUBE_AUTOSCALER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/minikube-cluster-autoscaler-addon/$PROFILE}"
BINARY="${MINIKUBE_AUTOSCALER_BINARY:-$PROJECT_ROOT/bin/minikube-cluster-autoscaler-addon}"
IMAGE="${MINIKUBE_AUTOSCALER_IMAGE:-minikube-cluster-autoscaler-addon:local}"
CONTAINER="minikube-cluster-autoscaler-addon-$PROFILE"
RELEASE=minikube-cluster-autoscaler-addon
CONFIG="${MINIKUBE_AUTOSCALER_CONFIG:-$STATE_DIR/config.json}"
CHART="$PROJECT_ROOT/charts/minikube-cluster-autoscaler-addon"

##
# Show the addon lifecycle and its explicit activation requirements.
# -> ret::exit_code
usage() {
    cat <<'EOF'
Usage: scripts/addon.sh COMMAND

  build    Build the optional native bridge and host provider container.
  init     Capture/protect existing VMs and create private journals and TLS identities.
  bridge   Run the native host VM bridge in this terminal; stop with Ctrl-C.
  enable   Start the provider container and install Cluster Autoscaler through Helm.
  test     Authenticate to the provider and check the Cluster Autoscaler rollout.
  status   Show provider state, container status, and worker placement.
  render   Render the Helm addon without accessing Kubernetes.
  disable  Remove Cluster Autoscaler and its container; retain VMs, journals and credentials.
  resume   Clear a recoverable provider error while its container is stopped.

init requires MINIKUBE_AUTOSCALER_CONFIG pointing to an edited examples/config.macos.json or examples/config.linux.json.
build accepts MINIKUBE_AUTOSCALER_BUILD_PROFILE=development|production (default: development in source checkouts, production in releases).
The native bridge must be running before enable; Docker cannot control macOS HVF directly.
This is a repository-local addon, not a compiled `minikube addons enable` extension.
EOF
}

##
# Fail without broad cleanup or implicit VM removal.
# message::string[] -> ret::never
fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

##
# Scope every Kubernetes operation to the configured cluster and namespace.
# args::string[] -> ret::exit_code
kube() {
    kubectl --context "$PROFILE" --namespace "$NAMESPACE" "$@"
}

##
# Build locked chart dependencies without changing global Helm repository settings.
# -> ret::exit_code
prepare_chart() {
    local cache="$PROJECT_ROOT/.cache/helm"
    mkdir -p "$cache/repository-cache"
    export HELM_REPOSITORY_CONFIG="$cache/repositories.yaml"
    export HELM_REPOSITORY_CACHE="$cache/repository-cache"
    if [[ -f "$CHART/charts/cluster-autoscaler-9.59.0.tgz" ]]; then return; fi
    helm repo add autoscaler https://kubernetes.github.io/autoscaler --force-update >&2
    helm dependency build "$CHART" --skip-refresh >&2
}

##
# Pin existing infrastructure controllers to protected base nodes before adding workers.
# -> ret::exit_code
protect_base() {
    local node namespace controller inventory
    while IFS= read -r node; do
        kube label node "$node" minikube-autoscaler.astrivant.com/pool=base --overwrite
    done < <(jq -r '.Base | keys[]' "$STATE_DIR/provider/state.json")
    for namespace in $(printf '%s\n' "$NAMESPACE" kube-system | sort -u); do
        inventory="$(kubectl --context "$PROFILE" --namespace "$namespace" get deployments,statefulsets -o name)"
        while IFS= read -r controller; do
            [[ -n "$controller" ]] || continue
            kubectl --context "$PROFILE" --namespace "$namespace" patch "$controller" --type=merge \
                -p '{"spec":{"template":{"spec":{"nodeSelector":{"minikube-autoscaler.astrivant.com/pool":"base"}}}}}'
        done <<<"$inventory"
    done
}

# Do not allow a lifecycle command to fall back to an untested host platform.
case "$(uname -s)/$(uname -m)" in
    Darwin/arm64 | Darwin/x86_64 | Linux/aarch64 | Linux/arm64 | Linux/x86_64) ;;
    *) fail 'Supported hosts are macOS/Linux on arm64/amd64' ;;
esac
[[ "$STATE_DIR" == /* ]] || fail 'State directory must be an absolute path'
umask 077

[[ $# -eq 1 ]] || {
    usage >&2
    exit 2
}
case "$1" in
    help | -h | --help)
        usage
        exit 0
        ;;
    build | init | bridge | enable | test | status | render | disable | resume) ;;
    *)
        usage >&2
        exit 2
        ;;
esac
[[ "$PROFILE" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ && ${#PROFILE} -le 40 ]] || fail 'Invalid profile'

if [[ "$1" == build ]]; then
    if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
        BUILD_PROFILE="${MINIKUBE_AUTOSCALER_BUILD_PROFILE-development}"
    else
        BUILD_PROFILE="${MINIKUBE_AUTOSCALER_BUILD_PROFILE-production}"
    fi
    case "$BUILD_PROFILE" in
        development)
            [[ -f "$PROJECT_ROOT/go.mod" ]] || fail 'Development profile requires a source checkout'
            mkdir -p "$(dirname "$BINARY")"
            go -C "$PROJECT_ROOT" build -mod=readonly -trimpath -o "$BINARY" .
            ;;
        production)
            [[ -x "$BINARY" && -f "$PROJECT_ROOT/bin/provider-linux" ]] || fail 'Production profile requires the native bridge and bin/provider-linux from a release archive'
            ;;
        *) fail 'Build profile must be development or production' ;;
    esac
    docker build --file "$PROJECT_ROOT/Dockerfile" --target "$BUILD_PROFILE" --tag "$IMAGE" "$PROJECT_ROOT"
    exit 0
fi
[[ -f "$CONFIG" ]] || fail 'Set MINIKUBE_AUTOSCALER_CONFIG to an edited example configuration, then run init'
[[ "$(jq -r '.profile' "$CONFIG")" == "$PROFILE" ]] || fail 'Configuration profile differs from MINIKUBE_AUTOSCALER_PROFILE'
NAMESPACE="$(jq -er '.namespace' "$CONFIG")"
ADDRESS="$(jq -er '.listen' "$CONFIG")"
[[ "$NAMESPACE" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || fail 'Invalid namespace'

case "$1" in
    init)
        [[ -x "$BINARY" ]] || fail 'Run build first'
        "$BINARY" --mode=init --config="$CONFIG" --state-dir="$STATE_DIR"
        protect_base
        ;;
    bridge | resume)
        if [[ "$1" == resume ]] && docker container inspect "$CONTAINER" >/dev/null 2>&1; then
            [[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER")" == false ]] || fail 'Disable the addon before resuming'
        fi
        exec "$BINARY" --mode="$1" --config="$CONFIG" --state-dir="$STATE_DIR"
        ;;
    enable)
        [[ -f "$STATE_DIR/provider/state.json" ]] || fail 'Run init first'
        [[ "$(jq -r '.Error' "$STATE_DIR/provider/state.json")" == '' ]] || fail 'Provider is paused; inspect status and use resume after repair'
        protect_base
        # Validate host connectivity before starting a container that can request VMs.
        "$BINARY" --mode=bridge-check --config="$CONFIG" --state-dir="$STATE_DIR"

        # Mount only provider-owned state and its two TLS identities, never the
        # Docker socket, kubeconfig, SSH keys, Minikube disks or the CA private key.
        if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
            docker start "$CONTAINER" >/dev/null
        else
            docker run --detach --name "$CONTAINER" --read-only --cap-drop=ALL \
                --security-opt=no-new-privileges --pids-limit=64 --memory=256m --cpus=0.5 \
                --user "$(id -u):$(id -g)" --add-host=host.docker.internal:host-gateway \
                --publish "$ADDRESS:50051" --mount "type=bind,src=$STATE_DIR/provider,dst=/state" \
                "$IMAGE" >/dev/null
        fi
        "$BINARY" --mode=check --config="$CONFIG" --state-dir="$STATE_DIR"
        kube create secret generic "$RELEASE-client" \
            --from-file="$STATE_DIR/client/tls/ca.crt" \
            --from-file="$STATE_DIR/client/tls/autoscaler-client.crt" \
            --from-file="$STATE_DIR/client/tls/autoscaler-client.key" \
            --dry-run=client -o yaml | kube apply -f - >/dev/null
        prepare_chart
        kube apply --server-side --field-manager=minikube-cluster-autoscaler-addon \
            -f "$CHART/provisioningrequests.yaml"
        timeout_seconds="$(jq -r '.provisionTimeoutSeconds + 60' "$CONFIG")"
        helm upgrade --install "$RELEASE" "$CHART" --kube-context "$PROFILE" --namespace "$NAMESPACE" \
            --set-string "provider.address=$ADDRESS" \
            --set-string "cluster-autoscaler.autoDiscovery.clusterName=$PROFILE" \
            --set-string "cluster-autoscaler.extraArgs.max-node-provision-time=${timeout_seconds}s" \
            --wait --timeout 5m
        ;;
    test)
        "$BINARY" --mode=check --config="$CONFIG" --state-dir="$STATE_DIR"
        kube rollout status deployment/"$RELEASE" --timeout 2m
        ;;
    status)
        jq '{ClusterUID, Base, Workers, Error, LastChange}' "$STATE_DIR/provider/state.json"
        docker ps -a --filter "name=^/$CONTAINER$"
        kube get nodes -L minikube-autoscaler.astrivant.com/pool
        ;;
    render)
        prepare_chart
        helm template "$RELEASE" "$CHART" --namespace "$NAMESPACE" --kube-version 1.35.0 \
            --set-string "provider.address=$ADDRESS"
        ;;
    disable)
        # Stop decisions before the provider. No VMs or persistent state are removed.
        helm uninstall "$RELEASE" --kube-context "$PROFILE" --namespace "$NAMESPACE" --ignore-not-found --wait --timeout 5m
        if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
            docker stop --timeout 30 "$CONTAINER" >/dev/null
            docker rm "$CONTAINER" >/dev/null
        fi
        printf '%s\n' 'Addon disabled. VMs, base placement, TLS Secret, and journals were retained. Stop the bridge with Ctrl-C.'
        ;;
esac
