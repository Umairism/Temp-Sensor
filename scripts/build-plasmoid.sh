#!/usr/bin/env bash
#
# Build a distributable .plasmoid package (a ZIP of package/) in dist/.
#
# Usage: scripts/build-plasmoid.sh
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${REPO_ROOT}/package"
DIST_DIR="${REPO_ROOT}/dist"

python3 - "$PACKAGE_DIR" "$DIST_DIR" << 'PY'
import hashlib
import json
import sys
import xml.dom.minidom
import zipfile
from pathlib import Path

package_dir = Path(sys.argv[1]).resolve()
dist_dir = Path(sys.argv[2]).resolve()

metadata_path = package_dir / "metadata.json"
main_xml_path = package_dir / "contents/config/main.xml"

# --- Validate before packaging -------------------------------------------
metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
plugin = metadata.get("KPlugin", {})
required = ["Id", "Name", "Version", "License", "Category", "Description", "Icon"]
missing = [k for k in required if not plugin.get(k)]
if missing:
    sys.exit(f"metadata.json: missing required KPlugin keys: {', '.join(missing)}")
if metadata.get("KPackageStructure") != "Plasma/Applet":
    sys.exit("metadata.json: KPackageStructure must be 'Plasma/Applet'")
if metadata.get("X-Plasma-API-Minimum-Version") != "6.0":
    sys.exit("metadata.json: X-Plasma-API-Minimum-Version must be '6.0'")
# GPL licenses declared in metadata must ship a LICENSE file in the repo
if not (package_dir.parent / "LICENSE").is_file():
    sys.exit("LICENSE file missing at repository root")
xml.dom.minidom.parse(str(main_xml_path))

plugin_id = plugin["Id"]
version = plugin["Version"]

# --- Build the .plasmoid (ZIP) ------------------------------------------
dist_dir.mkdir(parents=True, exist_ok=True)
out = dist_dir / f"{plugin_id}-{version}.plasmoid"
if out.exists():
    out.unlink()

files = sorted(p for p in package_dir.rglob("*") if p.is_file())
if not files:
    sys.exit("package/ is empty — nothing to build")

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for f in files:
        zf.write(f, f.relative_to(package_dir).as_posix())

digest = hashlib.sha256(out.read_bytes()).hexdigest()
print(f"Wrote {out}")
print(f"  files:  {len(files)}")
print(f"  size:   {out.stat().st_size} bytes")
print(f"  sha256: {digest}")

# Sanity check: metadata.json must be at the archive root
with zipfile.ZipFile(out) as zf:
    names = zf.namelist()
    assert "metadata.json" in names, "metadata.json must be at the .plasmoid root"
    assert "contents/ui/main.qml" in names, "contents/ui/main.qml missing"
print("Archive layout OK")
PY
