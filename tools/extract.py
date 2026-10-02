#!/usr/bin/env python3
"""Split an .rbxlx place file into a readable source tree.

Layout produced under <out>/:
  place.rbxlx.tmpl      - the place file with every script body replaced by a
                          {{SCRIPT:<path>}} marker (everything else untouched)
  src/<service>/.../<Name>.lua  - one file per Script / LocalScript / ModuleScript

Use tools/build.py to turn the tree back into a place file.
"""
import re
import sys
from pathlib import Path

SCRIPT_RE = re.compile(
    r'(?P<head><Item class="(?P<cls>Script|LocalScript|ModuleScript)" referent="[^"]+">\s*<Properties>.*?'
    r'<ProtectedString name="Source"><!\[CDATA\[)(?P<body>.*?)(?P<tail>\]\]></ProtectedString>)',
    re.S,
)
NAME_RE = re.compile(r'<string name="Name">(.*?)</string>')
ITEM_OPEN = re.compile(r'<Item class="[^"]+" referent="[^"]+">')


def main(src, out):
    text = Path(src).read_text(encoding="utf-8")
    out = Path(out)
    (out / "src").mkdir(parents=True, exist_ok=True)

    # Track the instance path of each script by scanning items in order.
    stack = []
    pos = 0
    paths = []
    tokens = re.finditer(r'<Item class="([^"]+)" referent="[^"]+">|</Item>|<string name="Name">(.*?)</string>', text)
    pending_name_for = None
    depth_names = []
    for m in tokens:
        s = m.group(0)
        if s.startswith("<Item"):
            depth_names.append(None)
            pending_name_for = len(depth_names) - 1
            cls = m.group(1)
            depth_names[-1] = [cls, None, m.start()]
        elif s == "</Item>":
            depth_names.pop()
        else:
            # first Name after an Item open belongs to the innermost item
            if depth_names and depth_names[-1][1] is None:
                depth_names[-1][1] = m.group(2)
                depth_names[-1].append(m.start())
                cls = depth_names[-1][0]
                if cls in ("Script", "LocalScript", "ModuleScript"):
                    path = "/".join(d[1] for d in depth_names)
                    paths.append((m.start(), cls, path))

    # Replace script bodies in order.
    result = []
    last = 0
    idx = 0
    count = 0
    for m in SCRIPT_RE.finditer(text):
        # find the matching path: the first recorded path with start >= m.start()
        while paths[idx][0] < m.start():
            idx += 1
        _, cls, path = paths[idx]
        idx += 1
        rel = Path("src") / (path + ".lua")
        dest = out / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        # Script classes keep the class in a sidecar-free way: encode in filename suffix
        if cls == "Script":
            dest = dest.with_name(dest.stem + ".server.lua")
        elif cls == "LocalScript":
            dest = dest.with_name(dest.stem + ".client.lua")
        dest.write_text(m.group("body"), encoding="utf-8")
        marker = "{{SCRIPT:%s}}" % dest.relative_to(out).as_posix()
        result.append(text[last:m.start("body")])
        result.append(marker)
        last = m.end("body")
        count += 1
    result.append(text[last:])
    (out / "place.rbxlx.tmpl").write_text("".join(result), encoding="utf-8")
    print(f"extracted {count} scripts -> {out}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
