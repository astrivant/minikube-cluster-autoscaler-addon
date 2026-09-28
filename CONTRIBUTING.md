# Contributing

Use the Go version in `.go-version`. Install pre-commit, ShellCheck, actionlint
and shfmt, then run `make hooks`, `make test`, `make lint` and `make chart`.
CI pins pre-commit 4.3.0, actionlint 1.7.7 and shfmt 3.14.1.

Keep Go formatting idiomatic and explain ownership, concurrency and safety
decisions inline. Keep generated Kubernetes protobufs unchanged unless updating
the pinned upstream protocol. Add fake-backend tests for every lifecycle change;
unit tests must never call real Minikube to create or delete nodes.

Shell functions use the project's documentation convention:

```bash
##
# Describe the operation and relevant side effects.
# arg1::string -> ret::exit_code
example() {
    printf '%s\n' "$1"
}
```

Never commit state journals, private keys, tokens, kubeconfigs or cluster data.
Do not weaken identity checks, memory ceilings or deletion safeguards to make a
test pass. Document platform limitations rather than presenting cross-compilation
as proof of live VM support.
