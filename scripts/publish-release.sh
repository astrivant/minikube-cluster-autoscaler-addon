#!/usr/bin/env bash
# Publish only the four archives already built and validated by this pipeline run.
set -euo pipefail
version="$(bash scripts/validate-tag.sh "${1:-}")"
revision="${2:?expected source SHA}"
[[ "$(git rev-parse "refs/tags/$version^{commit}")" == "$revision" ]]
[[ "$(git rev-parse HEAD)" == "$revision" ]]
for target_os in darwin linux; do
    for target_arch in amd64 arm64; do
        test -s "dist/minikube-cluster-autoscaler-addon_${version#v}_${target_os}_${target_arch}.tar.gz"
    done
done
archives=(dist/*.tar.gz)
[[ ${#archives[@]} -eq 4 ]]
(cd dist && sha256sum ./*.tar.gz >checksums.txt && sha256sum --check checksums.txt)

# A draft may be retried after an interrupted upload. Published assets are immutable.
if metadata="$(gh release view "$version" --json isDraft 2>/dev/null)"; then
    jq -e '.isDraft == true' <<<"$metadata" >/dev/null || {
        printf 'Release %s is already published; refusing to overwrite its assets\n' "$version" >&2
        exit 1
    }
else
    gh release create "$version" --verify-tag --target "$revision" --title "$version" --generate-notes --draft
fi
gh release upload "$version" "${archives[@]}" dist/checksums.txt --clobber
if [[ "$version" == *-* ]]; then
    gh release edit "$version" --draft=false --prerelease --latest=false
else
    gh release edit "$version" --draft=false --prerelease=false --latest
fi
