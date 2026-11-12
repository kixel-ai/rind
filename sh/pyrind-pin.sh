#!/usr/bin/env bash
# Print where pyrind VERSION falls against pyrind-cryptography's pyrind
# requirement: `below` it, waiting for release-plz to bump pyrind, or
# `within` it. A pyrind past it is an error, since release.yml could then
# never install the pyrind that pyrind-cryptography's release needs.
#
# Usage: sh/pyrind-pin.sh VERSION
set -euo pipefail

version=${1:?usage: sh/pyrind-pin.sh VERSION}

cd "$(git rev-parse --show-toplevel)"

python3 - "$version" rind-python/cryptography/pyproject.toml <<'EOF'
import sys
import tomllib

from packaging.requirements import Requirement
from packaging.version import Version

version = Version(sys.argv[1])
with open(sys.argv[2], "rb") as f:
    deps = [Requirement(d) for d in tomllib.load(f)["project"]["dependencies"]]
spec = next(d.specifier for d in deps if d.name == "pyrind")

floors = [Version(s.version) for s in spec if s.operator in (">", ">=")]
if version in spec:
    print("within")
elif floors and all(version < floor for floor in floors):
    print("below")
else:
    sys.exit(f"error: pyrind {version} is past pyrind-cryptography's requirement pyrind{spec}")
EOF
