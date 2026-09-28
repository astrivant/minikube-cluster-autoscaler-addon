#!/usr/bin/env bash
# Use the committed lock, without changing the developer's Helm repositories.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export HELM_REPOSITORY_CONFIG="$PROJECT_ROOT/.cache/helm/repositories.yaml"
export HELM_REPOSITORY_CACHE="$PROJECT_ROOT/.cache/helm/repository-cache"
mkdir -p "$HELM_REPOSITORY_CACHE"
helm repo add autoscaler https://kubernetes.github.io/autoscaler --force-update
helm dependency build "$PROJECT_ROOT/charts/minikube-cluster-autoscaler-addon" --skip-refresh
