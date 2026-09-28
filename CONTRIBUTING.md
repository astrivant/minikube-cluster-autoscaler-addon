# Contributing

Use the Go version in `.go-version`, Python 3.13, pre-commit, ShellCheck, shfmt,
actionlint, Helm, and Node.js 24.

```bash
make hooks
make test
make vuln
make lint
make chart
make chart-docs
```

`make vuln` checks all Go dependency versions against the Go vulnerability
database. CI requires this scan to pass before verification and release.

`make chart-docs` uses pinned [Bitnami tooling](https://github.com/bitnami/readme-generator-for-helm)
to generate both charts' parameter tables and `values.schema.json` files from
`@param` comments in `values.yaml`. Put additional validation rules in each
chart's `values.schema.constraints.json`. Pre-commit regenerates these files;
CI checks that the committed outputs match.

The hypothesis-helm job varies the documented scalar values and array fields in
the Bitnami annotations, using the chart defaults with a test provider address. Every
render includes the upstream chart and is checked against Kubernetes 1.35 schemas.

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
