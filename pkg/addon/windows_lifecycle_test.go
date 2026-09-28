//go:build windows

package addon

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// The test executable doubles as each native CLI called by PowerShell. This
// exercises Windows argument passing without using Docker or a real cluster.
func TestMain(m *testing.M) {
	if log := os.Getenv("AUTOSCALER_TEST_TOOL_LOG"); log != "" {
		name := strings.TrimSuffix(strings.ToLower(filepath.Base(os.Args[0])), ".exe")
		call := append([]string{name}, os.Args[1:]...)
		data, _ := json.Marshal(call)
		f, err := os.OpenFile(log, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			os.Exit(1)
		}
		_, _ = f.Write(append(data, '\n'))
		_ = f.Close()
		if name == "kubectl" {
			if slices.Contains(call, "deployments,statefulsets") {
				fmt.Println("deployment/coredns")
			}
			if slices.Contains(call, "create") {
				fmt.Println("apiVersion: v1\nkind: Secret\nmetadata:\n  name: test")
			}
			if slices.Contains(call, "apply") && slices.Contains(call, "-") {
				_, _ = io.Copy(io.Discard, os.Stdin)
			}
		}
		if name == "docker" && slices.Contains(call, "ls") && os.Getenv("AUTOSCALER_TEST_CONTAINER") == "1" {
			fmt.Println("existing-container")
		}
		os.Exit(0)
	}
	os.Exit(m.Run())
}

func TestWindowsLifecycleHooks(t *testing.T) {
	root := filepath.Join(t.TempDir(), "bundle with spaces")
	state := filepath.Join(root, "state")
	tools := filepath.Join(root, "tools")
	for _, dir := range []string{filepath.Join(root, "scripts"), tools, filepath.Join(state, "provider"), filepath.Join(root, "charts/minikube-cluster-autoscaler-addon/charts")} {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	script, err := os.ReadFile("../../scripts/addon.ps1")
	if err != nil {
		t.Fatal(err)
	}
	files := map[string][]byte{
		"scripts/addon.ps1": script,
		"go.mod":            []byte("module fixture\n"),
		"charts/minikube-cluster-autoscaler-addon/charts/cluster-autoscaler-9.59.0.tgz": nil,
		"state/config.json":         []byte(`{"profile":"test-profile","namespace":"kube-system","listen":"192.168.65.254:50051","provisionTimeoutSeconds":900}`),
		"state/provider/state.json": []byte(`{"Base":{"test-profile":"uid"},"Error":""}`),
	}
	for name, data := range files {
		if err := os.WriteFile(filepath.Join(root, name), data, 0600); err != nil {
			t.Fatal(err)
		}
	}
	binary, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"docker", "kubectl", "helm", "go", "provider"} {
		destination := filepath.Join(tools, name+".exe")
		if err := os.Link(binary, destination); err != nil {
			data, err := os.ReadFile(binary)
			if err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(destination, data, 0700); err != nil {
				t.Fatal(err)
			}
		}
	}
	log := filepath.Join(root, "calls.jsonl")
	env := append(os.Environ(),
		"PATH="+tools+string(os.PathListSeparator)+os.Getenv("PATH"),
		"AUTOSCALER_TEST_TOOL_LOG="+log,
		"MINIKUBE_AUTOSCALER_PROFILE=test-profile",
		"MINIKUBE_AUTOSCALER_STATE_DIR="+state,
		"MINIKUBE_AUTOSCALER_CONFIG="+filepath.Join(state, "config.json"),
		"MINIKUBE_AUTOSCALER_BINARY="+filepath.Join(tools, "provider.exe"),
		"MINIKUBE_AUTOSCALER_IMAGE=provider:test",
	)
	for _, action := range []string{"build", "init", "enable", "disable"} {
		cmd := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-File", filepath.Join(root, "scripts/addon.ps1"), "-Action", action)
		cmd.Env = append([]string{}, env...)
		if action == "disable" {
			cmd.Env = append(cmd.Env, "AUTOSCALER_TEST_CONTAINER=1")
		}
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("%s: %v\n%s", action, err, output)
		}
	}
	data, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	observed := map[string]bool{}
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		var call []string
		if err := json.Unmarshal([]byte(line), &call); err != nil {
			t.Fatal(err)
		}
		if len(call) > 1 {
			observed[call[0]+" "+call[1]] = true
		}
		if call[0] == "kubectl" && (len(call) < 3 || call[1] != "--context" || call[2] != "test-profile") {
			t.Fatalf("unscoped Kubernetes command: %v", call)
		}
	}
	for _, command := range []string{"go -C", "docker build", "provider --mode=init", "docker run", "helm upgrade", "helm uninstall", "docker stop", "docker rm"} {
		if !observed[command] {
			t.Errorf("lifecycle omitted %s", command)
		}
	}
}
