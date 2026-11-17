"""Retain the original pull-request range and full-history secret policy."""
import re
import subprocess
import sys

base, head = sys.argv[1:]
if bool(base) != bool(head) or any(
    value and not re.fullmatch(r"[0-9a-f]{40}", value) for value in (base, head)
):
    raise SystemExit("Expected either both exact Git commits or neither")
command = ["gitleaks", "git", "--no-banner", "--redact"]
if base:
    command.append(f"--log-opts={base}..{head}")
raise SystemExit(subprocess.call([*command, "."]))
