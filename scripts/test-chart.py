#!/usr/bin/env python3
"""
Check the addon values contract against Helm rendering.
"""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

CHART = Path(__file__).resolve().parent.parent / "charts/minikube-cluster-autoscaler-addon"
DURATION_ARGS = (
    "max-node-provision-time",
    "scale-down-delay-after-add",
    "scale-down-unneeded-time",
    "scale-down-unready-time",
)


def render(*args: str, kubernetes_version: str = "1.35.0") -> subprocess.CompletedProcess[str]:
    """
    Render the addon with a reachable provider address and optional overrides.

    Args:
        *args (str): Additional Helm command-line arguments.
        kubernetes_version (str): Explicit server capability version for compatibility checks.

    Returns:
        subprocess.CompletedProcess[str]: Helm exit status and captured output.
    """
    return subprocess.run(
        [
            "helm",
            "template",
            "minikube-cluster-autoscaler-addon",
            str(CHART),
            "--kube-version",
            kubernetes_version,
            "--set-string",
            "provider.address=192.168.105.1:50051",
            *args,
        ],
        text=True,
        capture_output=True,
    )


class AddonValuesTests(unittest.TestCase):
    """
    Preserve schema rejection of recorded property-test counterexamples.
    """

    def test_invalid_values_fail_schema_validation(self) -> None:
        """
        Reject malformed documented inputs before template rendering.

        Returns:
            None: Assertions report any values contract violations.
        """
        invalid = [
            "provider.address=",
            "cluster-autoscaler.fullnameOverride=>0",
            "cluster-autoscaler.fullnameOverride=0",
            "cluster-autoscaler.fullnameOverride=true",
            "cluster-autoscaler.extraArgs.cloud-config=/etc/provider/\r0",
            'cluster-autoscaler.image.tag="',
            "cluster-autoscaler.image.tag=",
            "cluster-autoscaler.image.tag=" + "a" * 129,
        ]
        invalid.extend(f"cluster-autoscaler.extraArgs.{key}=\r0" for key in DURATION_ARGS)
        for value in invalid:
            with self.subTest(value=value):
                result = render("--set-string", value)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("values don't meet the specifications", result.stderr)
                self.assertNotIn("YAML parse error", result.stderr)

    def test_valid_durations_and_image_tags_render(self) -> None:
        """
        Accept zero, compound and fractional durations and standard image tags.

        Returns:
            None: Assertions report any values contract violations.
        """
        for duration in ("0", "16m", "1h30m", "500ms", "0.5s", ".5s", "1.s", "+1m"):
            with self.subTest(duration=duration):
                args = [arg for key in DURATION_ARGS for arg in ("--set-string", f"cluster-autoscaler.extraArgs.{key}={duration}")]
                result = render(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
        for tag in (
            "v1.35.0",
            "custom_1.2-rc",
            "a" * 128,
            "v1.37.0@sha256:bad6629616b9544dc5e358ee030f6d1d4047192e484d2e15bffb0c9fcd90b949",
        ):
            with self.subTest(tag=tag):
                version = "1.37.2" if tag.startswith("v1.37.") else "1.35.0"
                result = render("--set-string", f"cluster-autoscaler.image.tag={tag}", kubernetes_version=version)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_newer_servers_require_an_explicit_matching_image(self) -> None:
        """
        Prevent a direct Helm install from silently retaining the default 1.35 image on a newer server.

        Returns:
            None: The chart fails with an actionable selector command until an image is supplied.
        """
        for version in ("1.36.1", "1.37.2"):
            result = render(kubernetes_version=version)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("default Cluster Autoscaler image minor differs", result.stderr)


if __name__ == "__main__":
    unittest.main()
