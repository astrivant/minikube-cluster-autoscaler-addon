# Contributing

Use the Go version in `.go-version`, Python 3.13, pre-commit, ShellCheck, shfmt,
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

Python targets 3.13. Pre-commit runs Ruff lint/format, strict mypy, pydocstyle,
pydoclint, and the multiline docstring-layout check on scripts and chart code.
Use Google-style docstrings with typed `Args` and `Returns` sections, including
`Returns: None` for functions returning nothing. Put opening and closing
triple quotes on their own lines. Tool settings live in `pyproject.toml`;
pre-commit installs the pinned Python tools in isolated environments.

Shell functions document arguments and return values:

```bash
##
# Describe the operation.
# arg1::string -> ret::exit_code
example() {
    printf '%s\n' "$1"
}
```
