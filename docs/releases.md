# Releases

## Install an archive

Download the archive for your host OS (`darwin`, `linux` or `windows`) and architecture
(`amd64` or `arm64`) from [Releases](https://github.com/astrivant/minikube-cluster-autoscaler-addon/releases).
Each contains a native bridge, a same-architecture Linux provider binary, the
chart and dependency, scripts, examples, and documentation.

With GitHub CLI installed, replace `VERSION` with a published version:

```bash
VERSION=0.1.0
TARGET=darwin_arm64
ARCHIVE="minikube-cluster-autoscaler-addon_${VERSION}_${TARGET}"
gh release download "v$VERSION" --repo astrivant/minikube-cluster-autoscaler-addon \
  --pattern "$ARCHIVE.tar.gz" --pattern checksums.txt
grep "$ARCHIVE.tar.gz" checksums.txt | shasum -a 256 -c -
tar -xzf "$ARCHIVE.tar.gz"
mkdir -p "$HOME/.minikube/addons"
mv "$ARCHIVE" "$HOME/.minikube/addons/cluster-autoscaler"
minikube addons enable cluster-autoscaler
```

Use the Minikube build with the built-in addon integration. On first enable,
Minikube invokes the bundle's build hook, which selects the Dockerfile's
`production` target and packages the Linux binary. The install directory above
should be empty for a first installation; replace its contents when upgrading.
State lives separately from the bundle. See [integration](minikube-integration.md).

## Pipeline

[CI](../.github/workflows/ci.yml) resolves one source commit and calls reusable
stages for tests, builds, and publication. `CI verification` aggregates the
required stages and is the branch-protection check.

| Stage | Output |
| --- | --- |
| Test | Race tests and CLI checks on macOS, Linux and Windows; pre-commit, Helm lint/render, and hypothesis-helm reports for Kubernetes 1.35.0 |
| Build | Six platform archives; development and production container checks on Linux amd64/arm64 |
| Release | Verified archives, SHA-256 checksums, and generated notes |

Publication consumes the build artifacts from the same run. The release job
creates a draft, uploads assets, then publishes it. Interrupted draft uploads
can be retried; changes to published assets use a new version. Prerelease tags
leave the latest stable release unchanged. Publication uses `GITHUB_TOKEN`
with `contents: write` in the release stage.

Default-branch pushes combine statement coverage across all four host targets and
publish `gh-pages/badges/coverage.svg`. Generated protobufs are excluded. The
README badge links to the CI run history.

## Publish

```bash
make chart
make release VERSION=v0.1.0-alpha.1 GOOS=darwin GOARCH=arm64
git tag -a v0.1.0-alpha.1 -m 'Release v0.1.0-alpha.1'
git push origin v0.1.0-alpha.1
```

Tags follow `vMAJOR.MINOR.PATCH[-prerelease]`. Builds embed the version, source
commit, and commit date with CGO disabled and `-trimpath`. macOS binaries are
unsigned; archive timestamps use build-time filesystem metadata.

Update the autoscaler minor, Helm dependency, CRD, and protobuf sources together.
Dependabot tracks Go modules, GitHub Actions, and the Go container image.
