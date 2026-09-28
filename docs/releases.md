# Release maintenance

## Pipeline structure

Only `.github/workflows/ci.yml` has push/PR/manual triggers. The other workflows
are `workflow_call` stages, keeping one run link and one connected job diagram.
Source resolution pins every stage to one commit. Test and build stages run in
parallel; the `CI verification` aggregate rejects failed, cancelled or skipped
required stages. It is the stable required-check name for branch protection.

- Test: race tests and native CLI smoke checks on Linux/macOS, amd64/arm64;
  pre-commit, Helm validation and per-platform coverage artifacts.
- Build: four CGO-free archives, plus native Linux container smoke tests on
  both architectures. Every archive includes its platform's native bridge and
  same-architecture Linux provider binary, so downloads need no Go installation.
- Release: only pushed `vMAJOR.MINOR.PATCH[-prerelease]` tags, after verification.

The release job downloads already-built artifacts, verifies all four targets,
calculates `checksums.txt`, creates generated release notes in a draft, attaches
all files, then publishes. No rebuild happens during publication. A partially
uploaded draft can be retried; published assets are never overwritten by a rerun.
Create a new version to replace a published release. Prereleases do not move the
latest stable release. GitHub's repository token needs `contents: write` only
in the release stage. Releases contain no container-registry credentials.

## Before the first tag

1. Create the GitHub repository and push `main`.
2. Enable Actions and permit reusable workflows and the actions used here.
3. Require `CI verification` for the default branch and restrict tag pushes to
   trusted maintainers. Tags execute repository workflow code with release authority.
4. Run the complete pipeline once. Hosted-runner quotas depend on repository
   visibility and the account plan.
5. Push an annotated tag such as `v0.1.0-alpha.1`.

`.github/settings.yml` is optional configuration for the Probot Settings app;
checking it in alone does not configure branch protection. Dependabot monitors
Go modules, Actions and the source container. Updating Kubernetes dependencies
requires reviewing the pinned autoscaler minor, CRD and protobuf sources together.

## Local rehearsal

```bash
make chart
make release VERSION=v0.1.0-alpha.1 GOOS=darwin GOARCH=arm64
tar -tzf dist/minikube-cluster-autoscaler-addon_0.1.0-alpha.1_darwin_arm64.tar.gz
```

Builds embed version, source commit and source-commit date. Go code is built with
`-trimpath` and CGO disabled. Archive timestamps are not currently normalized,
so byte-identical archive reproducibility is not promised. Checksums protect
download integrity but are not independent signatures. macOS binaries are not
Developer-ID signed or notarized; use your organization's trusted-distribution
process if that is required. Nothing in the scripts disables Gatekeeper.

GitHub references: [reusable workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows),
[runner platforms](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[release creation](https://cli.github.com/manual/gh_release_create).
