#!/usr/bin/env python3
"""
Validate the rendered demo's traffic, metrics, and placement wiring.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CHART = ROOT / "charts/autoscaling-demo"


def render(*args: str, chart: Path = CHART) -> subprocess.CompletedProcess[str]:
    """
    Render a demo chart or archive with optional Helm arguments.

    Args:
        *args (str): Additional Helm command-line arguments.
        chart (Path): Chart directory or packaged archive to render.

    Returns:
        subprocess.CompletedProcess[str]: Helm exit status and captured output.
    """
    return subprocess.run(
        ["helm", "template", "scale-demo", str(chart), "--namespace", "autoscaling-demo", "--kube-version", "1.35.0", *args],
        text=True,
        capture_output=True,
    )


class DemoChartTests(unittest.TestCase):
    """
    Exercise chart wiring, packaged load profiles, and invalid configuration handling.
    """

    def test_traffic_metrics_and_three_node_placement(self) -> None:
        """
        Verify the traffic path and scheduling rules needed for two-worker scale-out.

        Returns:
            None: Assertions report any chart contract violations.
        """
        result = render()
        self.assertEqual(result.returncode, 0, result.stderr)
        objects = {obj["kind"]: obj for obj in yaml.safe_load_all(result.stdout)}
        deployment = objects["Deployment"]
        pod = deployment["spec"]["template"]
        labels = pod["metadata"]["labels"]
        self.assertTrue(objects["Service"]["spec"]["selector"].items() <= labels.items())
        hpa = objects["HorizontalPodAutoscaler"]["spec"]
        self.assertEqual(hpa["scaleTargetRef"]["name"], deployment["metadata"]["name"])
        self.assertEqual((hpa["minReplicas"], hpa["maxReplicas"]), (1, 3))
        self.assertNotIn("replicas", deployment["spec"])
        anti = pod["spec"]["affinity"]["podAntiAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"][0]
        self.assertEqual(anti["topologyKey"], "kubernetes.io/hostname")
        self.assertTrue(anti["labelSelector"]["matchLabels"].items() <= labels.items())
        job = objects["Job"]["spec"]["template"]["spec"]
        self.assertEqual(job["nodeSelector"]["minikube-autoscaler.astrivant.com/pool"], "base")
        env = {e["name"]: e["value"] for e in job["containers"][0]["env"]}
        self.assertEqual(env["TARGET_URL"], "http://" + objects["Service"]["metadata"]["name"])
        profile = json.loads(objects["ConfigMap"]["data"]["profile.json"])
        self.assertGreater(max(s["target"] for s in profile["stages"]), 0)
        self.assertEqual(profile["stages"][-1]["target"], 0)

    def test_packaged_profile_override(self) -> None:
        """
        Verify custom load profiles survive Helm packaging and selection.

        Returns:
            None: Assertions report any chart contract violations.
        """
        with tempfile.TemporaryDirectory() as tmp:
            chart = Path(tmp) / "chart"
            shutil.copytree(CHART, chart)
            profile = {"vus": 2, "duration": "30s"}
            (chart / "files/profiles/custom.json").write_text(json.dumps(profile))
            subprocess.run(["helm", "package", str(chart), "-d", tmp], check=True, capture_output=True)
            result = render("--set", "loadGenerator.profile=files/profiles/custom.json", chart=next(Path(tmp).glob("*.tgz")))
            self.assertEqual(result.returncode, 0, result.stderr)
            config = next(o for o in yaml.safe_load_all(result.stdout) if o["kind"] == "ConfigMap")
            self.assertEqual(json.loads(config["data"]["profile.json"]), profile)

    def test_stop_load_and_invalid_inputs(self) -> None:
        """
        Verify load shutdown and rejection of invalid chart inputs.

        Returns:
            None: Assertions report any chart contract violations.
        """
        result = render("--set", "loadGenerator.enabled=false")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Job", [o["kind"] for o in yaml.safe_load_all(result.stdout)])
        for value in ("loadGenerator.profile=files/profiles/missing.json", "hpa.minReplicas=4", "workload.workMilliseconds=0"):
            with self.subTest(value=value):
                self.assertNotEqual(render("--set", value).returncode, 0)
        with tempfile.TemporaryDirectory() as tmp:
            chart = Path(tmp) / "chart"
            shutil.copytree(CHART, chart)
            (chart / "files/profiles/default.json").write_text("not json")
            self.assertNotEqual(render(chart=chart).returncode, 0)


if __name__ == "__main__":
    unittest.main()
