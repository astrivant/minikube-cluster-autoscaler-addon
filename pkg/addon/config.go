// Package addon implements the Minikube autoscaler and its native host bridge.
package addon

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"regexp"
)

const poolLabel = "minikube-autoscaler.astrivant.com/pool"
const elasticTaint = "minikube-autoscaler.astrivant.com/elastic"
const groupID = "minikube-workers"

// supportedPlatform restricts host operation and release artifacts to tested targets.
func supportedPlatform(goos, goarch string) error {
	if (goos != "darwin" && goos != "linux") || (goarch != "amd64" && goarch != "arm64") {
		return fmt.Errorf("unsupported platform %s/%s: use macOS or Linux on amd64 or arm64", goos, goarch)
	}
	return nil
}

// Config makes destructive scope and host resource limits explicit, not inferred.
type Config struct {
	Profile                 string `json:"profile"`
	Namespace               string `json:"namespace"`
	Listen                  string `json:"listen"`
	MinWorkers              int    `json:"minWorkers"`
	MaxWorkers              int    `json:"maxWorkers"`
	MaxTotalMemoryMiB       int    `json:"maxTotalMemoryMiB"`
	ProvisionTimeoutSeconds int    `json:"provisionTimeoutSeconds"`
	CooldownSeconds         int    `json:"cooldownSeconds"`
}

func loadConfig(path string) (Config, error) {
	var c Config
	f, err := os.Open(path)
	if err != nil {
		return c, err
	}
	defer f.Close()
	d := json.NewDecoder(f)
	d.DisallowUnknownFields()
	if err = d.Decode(&c); err != nil {
		return c, err
	}
	if err = d.Decode(new(any)); err != io.EOF {
		return c, fmt.Errorf("configuration must contain exactly one JSON object")
	}
	label := regexp.MustCompile(`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`)
	if !label.MatchString(c.Profile) || len(c.Profile) > 40 || !label.MatchString(c.Namespace) || len(c.Namespace) > 63 {
		return c, fmt.Errorf("profile (max 40) and namespace (max 63) must be DNS labels")
	}
	host, port, err := net.SplitHostPort(c.Listen)
	ip := net.ParseIP(host)
	if err != nil || ip == nil || ip.IsUnspecified() || ip.IsMulticast() || port != "50051" {
		return c, fmt.Errorf("listen must be a specific host IP with port 50051, never a wildcard")
	}
	if c.MinWorkers < 0 || c.MaxWorkers < 1 || c.MaxWorkers > 16 || c.MinWorkers > c.MaxWorkers || c.MaxTotalMemoryMiB < 4096 {
		return c, fmt.Errorf("set 0 <= minWorkers <= maxWorkers <= 16 and an explicit total VM memory ceiling")
	}
	if c.ProvisionTimeoutSeconds < 60 || c.ProvisionTimeoutSeconds > 3600 || c.CooldownSeconds < 10 {
		return c, fmt.Errorf("provision timeout must be 60..3600 seconds; cooldown must be at least 10 seconds")
	}
	return c, nil
}
