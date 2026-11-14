"""Give each web build matching, versioned engine assets and progress metadata."""
import json
import re
import sys
from pathlib import Path

build_dir = Path(sys.argv[1])
revision = sys.argv[2]
if not re.fullmatch(r"[0-9a-f]{40}", revision):
    raise ValueError("Expected a full Git commit SHA")
html_path = build_dir / "index.html"
html = html_path.read_text()
match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
if match is None:
    raise ValueError("Godot export configuration missing")
config = json.loads(match[1])
base = "game-" + revision
for extension in ("js", "wasm", "pck"):
    (build_dir / ("index." + extension)).rename(build_dir / (base + "." + extension))
# Godot resolves audio worklets and optional worker scripts from executable.
for asset in build_dir.glob("index.*.js"):
    asset.rename(build_dir / (base + asset.name[len("index"):]))
config["executable"] = base
config["mainPack"] = base + ".pck"
config["fileSizes"] = {
    base + "." + extension: (build_dir / (base + "." + extension)).stat().st_size
    for extension in ("wasm", "pck")
}
html = html[:match.start(1)] + json.dumps(config, separators=(",", ":")) + html[match.end(1):]
html = html.replace('src="index.js"', 'src="' + base + '.js"')
html = html.replace("<head>", '<head><meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">', 1)
html_path.write_text(html)
(build_dir / ".nojekyll").touch()
