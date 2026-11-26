package addon

import (
	"strings"
	"testing"
)

func TestAutoscalerImageMatchesSupportedKubernetesMinor(t *testing.T) {
	for _, item := range []struct{ version, prefix string }{
		{"v1.35.0", "v1.35.3@sha256:"},
		{"v1.35.9", "v1.35.3@sha256:"},
		{"v1.36.5", "v1.36.2@sha256:"},
		{"v1.37.2", "v1.37.0@sha256:"},
	} {
		t.Run(item.version, func(t *testing.T) {
			image, err := AutoscalerImage(item.version)
			if err != nil || !strings.HasPrefix(image, item.prefix) || len(strings.Split(image, "sha256:")[1]) != 64 {
				t.Fatalf("image=%q error=%v", image, err)
			}
		})
	}
	for _, input := range []string{"", "invalid", "v1.34.0", "v1.38.0", "v1.37.0-beta.1", "v2.35.0"} {
		if _, err := AutoscalerImage(input); err == nil {
			t.Errorf("accepted unreviewed Kubernetes version %q", input)
		}
	}
}
