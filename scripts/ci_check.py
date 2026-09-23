"""Run Godot checks and fail even when Godot logs a script error with exit code 0."""
import os
import subprocess
import sys
from pathlib import Path

Path("build").mkdir(exist_ok=True)
Path("build/.gdignore").touch()

godot = os.environ.get("GODOT", "godot")
commands = [
    (["--headless", "--path", ".", "--editor", "--quit"], None),
    (["--headless", "--path", ".", "--script", "tests/test_runner.gd"], "0 failures"),
    (["--headless", "--path", ".", "--", "--smoke"], "UI_SMOKE_OK"),
]
for args, marker in commands:
    result = subprocess.run([godot, *args], text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=90)
    print(result.stdout)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        sys.exit(1)
    if marker and marker not in result.stdout:
        sys.exit(f"Missing completion marker: {marker}")
print("All Godot checks passed.")
