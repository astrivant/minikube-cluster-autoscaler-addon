package addon

import (
	"fmt"

	"k8s.io/apimachinery/pkg/util/version"
)

// AutoscalerImage selects a reviewed, immutable image tag for the Kubernetes minor.
// Pins were verified against registry.k8s.io and the corresponding upstream release
// tags. Unknown minors and prereleases need a reviewed compatibility update.
// The result is a tag@digest suffix, suitable for the chart's image.tag field.
func AutoscalerImage(kubernetesVersion string) (string, error) {
	v, err := version.ParseSemantic(kubernetesVersion)
	if err != nil || v.Major() != 1 || v.PreRelease() != "" {
		return "", fmt.Errorf("select a stable Kubernetes version with a reviewed Cluster Autoscaler image")
	}
	switch v.Minor() {
	case 35:
		return "v1.35.3@sha256:d45370bcadf7ae5e7a52281ccd79f7c0a72d0cf983b036bdc4f1afb2c34eebe3", nil
	case 36:
		return "v1.36.2@sha256:40931a15d371437b7c85c27096816346c4549ff9b9d7077c0d6c6118220214c4", nil
	case 37:
		return "v1.37.0@sha256:bad6629616b9544dc5e358ee030f6d1d4047192e484d2e15bffb0c9fcd90b949", nil
	default:
		return "", fmt.Errorf("no reviewed Cluster Autoscaler image for Kubernetes 1.%d; supported minors are 1.35, 1.36 and 1.37", v.Minor())
	}
}
