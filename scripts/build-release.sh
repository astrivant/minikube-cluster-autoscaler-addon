#!/usr/bin/env bash
# Produce an installable archive with a native bridge and Linux container binary.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
version="$(bash scripts/validate-tag.sh "${1:-}")"
target_os="${2:-}"
target_arch="${3:-}"
case "$target_os/$target_arch" in
    darwin/amd64 | darwin/arm64 | linux/amd64 | linux/arm64 | windows/amd64 | windows/arm64) ;;
    *)
        printf 'Unsupported release target: %s/%s\n' "$target_os" "$target_arch" >&2
        exit 2
        ;;
esac
revision="$(git rev-parse HEAD)"
build_date="$(git show -s --format=%cI HEAD)"
archive="minikube-cluster-autoscaler-addon_${version#v}_${target_os}_${target_arch}"
mkdir -p dist
release_stage="$(mktemp -d "$PROJECT_ROOT/dist/stage.XXXXXX")"
package="$release_stage/$archive"
mkdir -p "$package/bin" "$package/scripts" "$package/pkg/internal/protos"
suffix=""
if [[ "$target_os" == windows ]]; then suffix=.exe; fi
flags="-s -w -X main.version=$version -X main.commit=$revision -X main.buildDate=$build_date"
CGO_ENABLED=0 GOOS="$target_os" GOARCH="$target_arch" go build -mod=readonly -trimpath -buildvcs=false -ldflags "$flags" -o "$package/bin/minikube-cluster-autoscaler-addon$suffix" .
CGO_ENABLED=0 GOOS=linux GOARCH="$target_arch" go build -mod=readonly -trimpath -buildvcs=false -ldflags "$flags" -o "$package/bin/provider-linux" .
cp README.md LICENSE NOTICE Dockerfile .dockerignore "$package/"
cp pkg/internal/protos/LICENSE "$package/pkg/internal/protos/"
cp scripts/addon.sh scripts/addon.ps1 "$package/scripts/"
cp -R charts examples docs "$package/"
test -s "$package/charts/minikube-cluster-autoscaler-addon/charts/cluster-autoscaler-9.59.0.tgz"
chmod 755 "$package/bin/"* "$package/scripts/addon.sh"
tar -C "$release_stage" -czf "dist/$archive.tar.gz" "$archive"
printf 'Built dist/%s.tar.gz\n' "$archive"
# Leave the bounded staging directory under ignored dist/ for archive inspection.
