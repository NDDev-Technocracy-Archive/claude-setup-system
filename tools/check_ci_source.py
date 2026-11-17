"""Check authored Python and shell syntax without executing provider workloads."""
import ast
from pathlib import Path
import subprocess

for name in subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0"):
    if name.endswith(".py"):
        ast.parse(Path(name).read_text(encoding="utf-8"), filename=name)
    elif name.endswith(".sh"):
        subprocess.run(["bash", "-n", name], check=True)
print("Authored Python and shell sources parse.")
