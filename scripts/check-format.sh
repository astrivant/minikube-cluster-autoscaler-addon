#!/usr/bin/env bash
# Generated upstream protobufs are intentionally retained byte for byte.
set -euo pipefail
files=()
while IFS= read -r path; do files+=("$path"); done < <(git ls-files '*.go' ':!:internal/protos/*')
[[ ${#files[@]} -gt 0 ]]
unformatted="$(gofmt -l "${files[@]}")"
[[ -z "$unformatted" ]] || {
    printf 'Run gofmt on:\n%s\n' "$unformatted" >&2
    exit 1
}
