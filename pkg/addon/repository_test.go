package addon

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestExampleConfigurations(t *testing.T) {
	for _, path := range []string{"examples/config.macos.json", "examples/config.linux.json", "examples/config.linux-arm64.json"} {
		config, err := loadConfig(filepath.Join("../..", path))
		if err != nil {
			t.Fatalf("%s: %v", path, err)
		}
		if config.Profile != "minikube" || config.Namespace != "kube-system" || config.MaxTotalMemoryMiB != 20480 {
			t.Errorf("%s: unexpected standalone defaults", path)
		}
	}
}

func TestReleaseTagValidation(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("release tags are validated on the Unix archive-build runners")
	}
	for _, tag := range []string{"v0.1.0", "v1.20.3", "v0.1.0-alpha.1", "v1.0.0-rc.2", "v1.0.0-0"} {
		result, err := exec.Command("bash", "../../scripts/validate-tag.sh", tag).CombinedOutput()
		if err != nil || strings.TrimSpace(string(result)) != tag {
			t.Errorf("valid tag %q rejected: %v %s", tag, err, result)
		}
	}
	for _, tag := range []string{"", "latest", "1.0.0", "v01.0.0", "v1.0.0-01", "v1.0.0-", "v1.0.0-a..b", "v1.0.0/../../x", "v1.0.0 $(id)", "v1.0.0\n"} {
		if err := exec.Command("bash", "../../scripts/validate-tag.sh", tag).Run(); err == nil {
			t.Errorf("unsafe or invalid tag %q accepted", tag)
		}
	}
}

func TestLifecycleHelpNeedsNoClusterOrCredentials(t *testing.T) {
	command := exec.Command("bash", "../../scripts/addon.sh", "help")
	help := "Usage: scripts/addon.sh"
	if runtime.GOOS == "windows" {
		command = exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-File", "../../scripts/addon.ps1", "-Action", "help")
		help = "Usage: addon.ps1"
	}
	command.Env = append(os.Environ(), "MINIKUBE_AUTOSCALER_STATE_DIR="+t.TempDir(), "MINIKUBE_AUTOSCALER_CONFIG=/does-not-exist")
	output, err := command.CombinedOutput()
	if err != nil || !strings.Contains(string(output), help) {
		t.Fatalf("help should be safe without a cluster: %v %s", err, output)
	}
}

func TestToolchainVersionIsConsistent(t *testing.T) {
	data, err := os.ReadFile("../../.go-version")
	if err != nil {
		t.Fatal(err)
	}
	version := strings.TrimSpace(string(data))
	for path, expected := range map[string]string{"Dockerfile": "FROM golang:" + version, "go.mod": "toolchain go" + version} {
		data, err := os.ReadFile(filepath.Join("../..", path))
		if err != nil || !strings.Contains(string(data), expected) {
			t.Errorf("%s must match .go-version (%s): %v", path, version, err)
		}
	}
}
