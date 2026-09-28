#!/usr/bin/env bash
# Keep untrusted refs out of archive names and linker flags.
set -euo pipefail

tag="${1:-}"
pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-([0-9A-Za-z-]+\.)*[0-9A-Za-z-]+)?$'
[[ "$tag" =~ $pattern ]] || {
    printf 'Expected vMAJOR.MINOR.PATCH with an optional prerelease suffix, got %s\n' "$tag" >&2
    exit 2
}
if [[ "$tag" == *-* ]]; then
    prerelease="${tag#*-}"
    IFS=. read -r -a identifiers <<<"$prerelease"
    for identifier in "${identifiers[@]}"; do
        [[ ! "$identifier" =~ ^0[0-9]+$ ]] || {
            printf 'Numeric prerelease identifiers must not have leading zeroes\n' >&2
            exit 2
        }
    done
fi
printf '%s\n' "$tag"
