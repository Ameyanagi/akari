#!/usr/bin/env python3
"""Run pinned downstream consumers with baseline and checked-out Akari sources."""

from __future__ import annotations

import hashlib
import json
import platform
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "downstream"
OUTPUT = ROOT / ".pixi" / "downstream-proof"


def run(*args: str, cwd: Path = ROOT) -> str:
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"Command failed: {args!r}\n{result.stdout}{result.stderr}")
    return result.stdout.strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_digest(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted((root / "src" / "akari").rglob("*.mojo")):
        digest.update(path.relative_to(root).as_posix().encode() + b"\0")
        digest.update(path.read_bytes() + b"\0")
    return digest.hexdigest()


def checkout(name: str, pin: dict, directory: Path) -> Path:
    revision = pin["revision"]
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError(f"{name} must use a full immutable commit SHA")
    expected_url = f"https://github.com/Ameyanagi/{name}.git"
    if pin["url"] != expected_url:
        raise ValueError(f"Unexpected source URL for {name}: {pin['url']}")
    repo = directory / name
    repo.mkdir()
    run("git", "init", "--quiet", str(repo))
    run("git", "-C", str(repo), "fetch", "--quiet", "--depth=1", expected_url, revision)
    run("git", "-C", str(repo), "checkout", "--quiet", "--detach", "FETCH_HEAD")
    actual = run("git", "-C", str(repo), "rev-parse", "HEAD")
    if actual != revision:
        raise RuntimeError(f"{name}: expected {revision}, got {actual}")
    print(f"Pinned {name}: {actual}", flush=True)
    return repo


def verify_svg(path: Path) -> list[dict]:
    root = ET.parse(path).getroot()
    expected = ["#1f77b4", "#440154", "#21918c", "#fde725"]
    series = [
        element for element in root.iter("{http://www.w3.org/2000/svg}polyline")
        if element.get("class", "").startswith("sen-series-")
    ]
    if len(series) != 4:
        raise AssertionError(f"Expected four rendered series, got {len(series)}")
    observed = []
    for index, (element, color) in enumerate(zip(series, expected)):
        opacity = float(element.get("opacity", "1")) * float(element.get("stroke-opacity", "1"))
        points = element.get("points", "").split()
        if (element.get("class"), element.get("stroke"), opacity, len(points)) != (
            f"sen-series-{index}", color, 0.5 if index == 3 else 1.0, 3
        ):
            raise AssertionError(f"Unexpected Sen series {index}: {element.attrib}")
        observed.append({"series": index, "color": color, "opacity": opacity, "points": 3})
    return observed


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report_path = OUTPUT / "report.json"
    report_path.unlink(missing_ok=True)
    pins = json.loads((FIXTURES / "pins.json").read_text())
    compiler = run("mojo", "--version")
    if compiler != pins["mojo"]:
        raise RuntimeError(f"Expected {pins['mojo']}, got {compiler}; use pixi run --locked")
    report = {
        "compiler": compiler,
        "platform": platform.platform(),
        "pins": pins["repositories"],
        "checkout_revision": run("git", "rev-parse", "HEAD"),
        "checkout_status": run("git", "status", "--porcelain"),
        "inputs_sha256": {
            str(path.relative_to(ROOT)): sha256(path)
            for path in [Path(__file__).resolve(), *sorted(FIXTURES.iterdir())]
            if path.is_file()
        },
        "runs": {},
    }
    # Fresh checkouts avoid silently reusing changed or stale local consumers.
    with tempfile.TemporaryDirectory(prefix="akari-downstream-") as temp:
        repositories = {
            name: checkout(name, pin, Path(temp))
            for name, pin in pins["repositories"].items()
        }
        for mode, akari in [("baseline", repositories["akari"]), ("checkout", ROOT)]:
            destination = OUTPUT / mode
            destination.mkdir(exist_ok=True)
            (destination / "sen.svg").unlink(missing_ok=True)
            results = {"akari_source_sha256": source_digest(akari), "consumers": {}}
            for consumer, fixture in [("sen", "sen_palette"), ("kagerou", "kagerou_alpha")]:
                binary = destination / fixture
                command = [
                    "mojo", "build", "--Werror",
                    "-I", str(akari / "src"),
                    "-I", str(repositories[consumer] / "src"),
                    str(FIXTURES / f"{fixture}.mojo"), "-o", str(binary),
                ]
                print(f"Checking {mode} Akari with pinned {consumer}", flush=True)
                run(*command)
                output = run(str(binary), cwd=destination)
                log = destination / f"{consumer}.log"
                log.write_text(output + "\n")
                results["consumers"][consumer] = {
                    "build_command": command, "output": output, "log_sha256": sha256(log)
                }
                print(output, flush=True)
            svg = destination / "sen.svg"
            results["sen_series"] = verify_svg(svg)
            results["sen_svg_sha256"] = sha256(svg)
            report["runs"][mode] = results
    report["status"] = "passed"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS downstream proof: {report_path}", flush=True)


if __name__ == "__main__":
    main()
