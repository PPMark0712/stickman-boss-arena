"""Godot 4.7.2 import, regression checks and Web release. Python 3.9+, no packages."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / "test-results"
VERSION = "4.7.2"


def godot_path() -> str:
    candidate = os.environ.get("GODOT") or shutil.which("godot") or shutil.which("godot4")
    if not candidate and sys.platform == "darwin":
        candidate = "/Applications/Godot.app/Contents/MacOS/Godot"
    if not candidate or not Path(candidate).is_file():
        raise RuntimeError("Install Godot 4.7.2 or set GODOT to its executable path.")
    version = subprocess.check_output([candidate, "--version"], text=True).strip()
    if not version.startswith(VERSION + ".stable"):
        raise RuntimeError(f"Expected Godot {VERSION} stable, found {version}.")
    return candidate


def run(godot: str, name: str, arguments: list[str], marker: str = "") -> None:
    LOGS.mkdir(exist_ok=True)
    log = LOGS / f"{name}.log"
    command = [godot, "--headless", "--path", str(ROOT), "--log-file", str(log), *arguments]
    environment = os.environ.copy()
    # Keep editor settings and user:// writes inside the workspace. This also
    # makes local and CI runs independent of an existing Godot installation.
    environment["HOME"] = str(ROOT / ".tools/home")
    Path(environment["HOME"]).mkdir(parents=True, exist_ok=True)
    print(f"Running {name}...", flush=True)
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
        timeout=180,
    )
    output = result.stdout + result.stderr
    (LOGS / f"{name}-console.log").write_text(output, encoding="utf-8")
    logged_output = log.read_text(encoding="utf-8") if log.exists() else ""
    diagnostic_output = output + "\n" + logged_output
    # GDScript parse/runtime errors can still return exit code 0.
    if (
        result.returncode
        or re.search(r"(?:SCRIPT ERROR:|ERROR:)", diagnostic_output)
        or (marker and marker not in diagnostic_output)
    ):
        print(output)
        raise RuntimeError(f"{name} failed; see {LOGS}.")
    for line in output.splitlines():
        if "checks," in line:
            print(line, flush=True)
    print(f"{name}: OK", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task", choices=["test", "web", "all"], nargs="?", default="all")
    args = parser.parse_args()
    godot = godot_path()
    (ROOT / "build").mkdir(exist_ok=True)
    (ROOT / "build/.gdignore").touch()
    run(godot, "import", ["--editor", "--import"])
    if args.task in ("test", "all"):
        for suite in ("player", "gameplay"):
            arguments = [
                "--fixed-fps",
                "120",
                "--script",
                f"tests/{suite}_test.gd",
            ]
            run(godot, suite, arguments, "0 failures")
    if args.task in ("web", "all"):
        templates = ROOT / ".tools/templates"
        template_modes = ("debug", "release")
        if not all(
            (templates / f"web_nothreads_{mode}.zip").exists()
            for mode in template_modes
        ):
            raise RuntimeError("Run python3 tools/fetch_templates.py before exporting.")
        target = ROOT / "build/web"
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True, exist_ok=True)
        run(godot, "export", ["--export-release", "Web", str(target / "index.html")])
        for filename in ("index.html", "index.js", "index.wasm", "index.pck"):
            if not (target / filename).is_file() or (target / filename).stat().st_size == 0:
                raise RuntimeError(f"Missing exported artifact: {filename}")
        (target / ".nojekyll").touch()
        shutil.copy(ROOT / "LICENSE", target / "LICENSE.txt")
        shutil.copy(ROOT / "assets/fonts/OFL.txt", target / "FONT-LICENSE.txt")
        size = sum(file.stat().st_size for file in target.iterdir() if file.is_file())
        print(f"Web ready: {target} ({size / 1024 / 1024:.1f} MiB)")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)
