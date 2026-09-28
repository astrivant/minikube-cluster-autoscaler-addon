# Contributing

Use the Go version in `.go-version`, plus pre-commit, ShellCheck, shfmt,
actionlint, and Helm.

```bash
make hooks
make test
make lint
make chart
```

Implementation and tests live in `pkg/addon/`. Explain ownership and concurrency
decisions inline, and cover lifecycle changes with the fake provisioning backend.
Use [scale-out validation](docs/operations.md#scale-outs-and-scale-downs) for
host-driver integration. Update generated files in `pkg/internal/protos/` when
upgrading the pinned upstream protocol.

Shell functions document arguments and return values:

```bash
##
# Describe the operation.
# arg1::string -> ret::exit_code
example() {
    printf '%s\n' "$1"
}
```
