"""Build the standalone playground page.

    python web/playground/build.py

Compiles rootplc-wasm for wasm32-unknown-unknown and writes
web/playground/dist/rootplc-playground.html: one self-contained file (the
WebAssembly module is inlined as base64), so it opens from disk or any
static host with nothing to install.
"""
import base64
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]


def main() -> int:
    r = subprocess.run(["cargo", "build", "--release", "--target", "wasm32-unknown-unknown", "-p", "rootplc-wasm"],
                       cwd=REPO)
    if r.returncode:
        return r.returncode
    wasm = REPO / "target" / "wasm32-unknown-unknown" / "release" / "rootplc_wasm.wasm"
    examples = []
    for f in sorted((HERE / "examples").glob("*.st")):
        text = f.read_text(encoding="utf-8")
        head = re.match(r"\(\*(.*?)\*\)\s*", text, re.S)
        meta = dict(re.findall(r"^\s*(title|hint):\s*(.+?)\s*$", head.group(1), re.M)) if head else {}
        examples.append({"title": meta.get("title", f.stem), "hint": meta.get("hint", ""),
                         "source": text[head.end():] if head else text})
    page = (HERE / "playground.html").read_text(encoding="utf-8")
    page = page.replace("__WASM_BASE64__", base64.b64encode(wasm.read_bytes()).decode())
    page = page.replace("__EXAMPLES_JSON__", json.dumps(examples).replace("</", "<\\/"))
    out = HERE / "dist" / "rootplc-playground.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size // 1024} KB, {len(examples)} examples)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
