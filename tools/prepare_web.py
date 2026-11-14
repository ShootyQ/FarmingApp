"""Give each web build matching, versioned engine assets and progress metadata."""
import json
import re
import sys
import shutil
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
    shutil.copy2(build_dir / ("index." + extension), build_dir / (base + "." + extension))
# Godot resolves audio worklets and optional worker scripts from executable.
for asset in build_dir.glob("index.*.js"):
    shutil.copy2(asset, build_dir / (base + asset.name[len("index"):]))
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

# Old cached HTML still requests index.js / index.wasm / index.pck. Keep
# those aliases, plus the last build's immutable URLs for open browser tabs.
if len(sys.argv) > 3:
    previous = Path(sys.argv[3])
    previous_html = (previous / "index.html").read_text()
    previous_match = re.search(r'"executable":"(game-[0-9a-f]{40})"', previous_html)
    if previous_match:
        for asset in previous.glob(previous_match[1] + ".*"):
            shutil.copy2(asset, build_dir / asset.name)
# A separate entry point bypasses a stale cached index.html without touching saves.
(build_dir / "play.html").write_text(html)
