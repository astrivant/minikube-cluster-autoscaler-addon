# Security

The native bridge uses the host user's Minikube and kubectl credentials to
create and delete workers in the configured cluster. The provider container
mounts its own state and TLS identities. Distinct mutual-TLS roles authenticate
the autoscaler and bridge links; independent ownership journals authorize
node operations. See [architecture](docs/architecture.md).

Keep the state directory private and restrict host ports 50051 and 50052 to
the cluster and local container network. Certificates expire after one year;
rotation is manual.

Report vulnerabilities through the repository's private GitHub security
advisories. Include the affected version and reproduction steps, with
credentials and cluster data redacted.
