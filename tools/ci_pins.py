"""Read exact CI compiler identities from the existing project declarations."""
import json
import os
from pathlib import Path
import re
import tomllib

root = Path(__file__).resolve().parent.parent
rust = tomllib.loads((root / "rust-toolchain.toml").read_text())["toolchain"]["channel"]
minimum = tomllib.loads((root / "Cargo.toml").read_text())["workspace"]["package"]["rust-version"]
msrv = minimum + ".0" if minimum.count(".") == 1 else minimum
values = {"rust": rust, "msrv": msrv}
if not all(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", value) for value in values.values()):
    raise SystemExit("CI requires exact compiler versions from the project declarations")
if output := os.environ.get("GITHUB_OUTPUT"):
    with Path(output).open("a") as stream:
        for name, value in values.items():
            stream.write(f"{name}={value}\n")
print(json.dumps(values, sort_keys=True))
