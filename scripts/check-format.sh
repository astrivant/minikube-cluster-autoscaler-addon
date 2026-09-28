#!/usr/bin/env bash
# Generated upstream protobufs are intentionally retained byte for byte.
set -euo pipefail
files=()
while IFS= read -r path; do
    if [[ -f "$path" ]]; then files+=("$path"); fi
done < <(git ls-files --cached --others --exclude-standard --deduplicate '*.go' ':!:pkg/internal/protos/*')
[[ ${#files[@]} -gt 0 ]]
unformatted="$(gofmt -l "${files[@]}")"
[[ -z "$unformatted" ]] || {
    printf 'Run gofmt on:\n%s\n' "$unformatted" >&2
    exit 1
}
