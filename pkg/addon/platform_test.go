package addon

import "testing"

func TestSupportedDrivers(t *testing.T) {
	for _, fixture := range []struct {
		os, arch, driver, network string
		valid                     bool
	}{
		{"darwin", "arm64", "qemu2", "socket_vmnet", true},
		{"darwin", "amd64", "qemu2", "socket_vmnet", true},
		{"linux", "amd64", "kvm2", "", true},
		{"linux", "arm64", "docker", "", true},
		{"linux", "arm64", "kvm2", "", false},
		{"linux", "amd64", "docker", "", false},
		{"darwin", "arm64", "qemu2", "builtin", false},
		{"darwin", "arm64", "docker", "", false},
		{"windows", "amd64", "docker", "", false},
	} {
		err := supportedDriver(fixture.os, fixture.arch, fixture.driver, fixture.network)
		if (err == nil) != fixture.valid {
			t.Errorf("%+v: unexpected validation result %v", fixture, err)
		}
	}
}

func TestSupportedPlatforms(t *testing.T) {
	for _, platform := range []struct{ os, arch string }{
		{"darwin", "amd64"}, {"darwin", "arm64"}, {"linux", "amd64"}, {"linux", "arm64"},
	} {
		if err := supportedPlatform(platform.os, platform.arch); err != nil {
			t.Fatal(err)
		}
	}
	for _, platform := range []struct{ os, arch string }{
		{"windows", "amd64"}, {"freebsd", "arm64"}, {"linux", "386"}, {"darwin", "arm"},
	} {
		if err := supportedPlatform(platform.os, platform.arch); err == nil {
			t.Fatalf("accepted unsupported target %s/%s", platform.os, platform.arch)
		}
	}
}
