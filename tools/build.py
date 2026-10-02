#!/usr/bin/env python3
"""Rebuild the .rbxlx place file from the source tree.

  python3 tools/build.py <tree-dir> <out.rbxlx>

<tree-dir> contains place.rbxlx.tmpl and src/**.lua (see tools/extract.py).

* Every {{SCRIPT:path}} marker in the template is replaced by that file's contents.
* IronClash/assets/FighterAssets.xml (from tools/import_assets.py) is inserted as
  ReplicatedStorage/FighterAssets.
* Any .lua file under src/ that the template does not mention is a NEW script: it is inserted as a
  Script / LocalScript / ModuleScript item (chosen from the file suffix) under the instance whose
  path matches the file's directory.  A directory named like a script file holds that script's
  children, exactly as extract.py lays things out.
    X.lua         -> ModuleScript
    X.server.lua  -> Script
    X.client.lua  -> LocalScript
"""
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

TOKEN_RE = re.compile(r'<Item class="([^"]+)" referent="[^"]+">|</Item>|<string name="Name">(.*?)</string>')


def scan_items(text):
    """Return {path: (open_pos, close_pos, indent)} for every named item in the template."""
    stack = []
    out = {}
    for m in TOKEN_RE.finditer(text):
        s = m.group(0)
        if s.startswith("<Item"):
            line_start = text.rfind("\n", 0, m.start()) + 1
            stack.append({"cls": m.group(1), "name": None, "open": m.start(), "indent": text[line_start:m.start()]})
        elif s == "</Item>":
            it = stack.pop()
            if it["name"] is not None:
                path = "/".join(x["name"] for x in stack + [it])
                out[path] = (it["open"], m.start(), it["indent"])
        elif stack and stack[-1]["name"] is None:
            stack[-1]["name"] = m.group(2)
    return out


def item_xml(cls, name, body, referent, indent):
    t = indent
    return (
        f'{t}<Item class="{cls}" referent="{referent}">\n'
        f"{t}\t<Properties>\n"
        f'{t}\t\t<string name="Name">{escape(name)}</string>\n'
        f'{t}\t\t<ProtectedString name="Source"><![CDATA[{body}]]></ProtectedString>\n'
        f"{t}\t</Properties>\n"
        f"{t}</Item>\n"
    )


def main(tree, out):
    tree = Path(tree)
    text = (tree / "place.rbxlx.tmpl").read_text(encoding="utf-8")
    srcdir = tree / "src"

    used = set(re.findall(r"\{\{SCRIPT:([^}]+)\}\}", text))
    known_rel = {Path(u).as_posix() for u in used}

    # ---- new scripts -------------------------------------------------------------------
    new_files = []
    for p in sorted(srcdir.rglob("*.lua")):
        rel = p.relative_to(tree).as_posix()
        if rel not in known_rel:
            new_files.append(p)

    items = scan_items(text)
    refs = [int(r, 16) for r in re.findall(r'referent="RBX([0-9A-Fa-f]+)"', text)]
    next_ref = max(refs + [0xFF]) + 1

    inserts = []  # (position, xml)
    for p in new_files:
        rel = p.relative_to(srcdir)
        fname = rel.name
        if fname.endswith(".server.lua"):
            cls, name = "Script", fname[: -len(".server.lua")]
        elif fname.endswith(".client.lua"):
            cls, name = "LocalScript", fname[: -len(".client.lua")]
        else:
            cls, name = "ModuleScript", fname[: -len(".lua")]
        parent = "/".join(rel.parts[:-1])
        if parent not in items:
            raise SystemExit(f"{rel}: no parent instance '{parent}' in the place template")
        _, close_pos, parent_indent = items[parent]
        body = p.read_text(encoding="utf-8")
        if "]]>" in body:
            raise SystemExit(f"{rel}: script contains ']]>' which cannot live in a CDATA block")
        # insert just before the parent's closing tag (which sits at the parent's indent)
        line_start = text.rfind("\n", 0, close_pos) + 1
        xml = item_xml(cls, name, body, "RBX%08X" % next_ref, parent_indent + "\t")
        next_ref += 1
        inserts.append((line_start, xml))
    for pos, xml in sorted(inserts, key=lambda x: -x[0]):
        text = text[:pos] + xml + text[pos:]

    # ---- fighter body models (tools/import_assets.py) -------------------------------------
    assets = tree / "assets" / "FighterAssets.xml"
    if assets.exists():
        if "ReplicatedStorage" not in items:
            raise SystemExit("no ReplicatedStorage in the place template")
        a_xml = assets.read_text(encoding="utf-8").strip() + "\n"
        # scan_items positions are stale after the script inserts, so find ReplicatedStorage again
        items2 = scan_items(text)
        _, close_pos, _ = items2["ReplicatedStorage"]
        line_start = text.rfind("\n", 0, close_pos) + 1
        text = text[:line_start] + a_xml + text[line_start:]

    # ---- existing script bodies --------------------------------------------------------
    def sub(m):
        body = (tree / m.group(1)).read_text(encoding="utf-8")
        if "]]>" in body:
            raise SystemExit(f"{m.group(1)}: script contains ']]>' which cannot live in a CDATA block")
        return body

    text = re.sub(r"\{\{SCRIPT:([^}]+)\}\}", sub, text)
    Path(out).write_text(text, encoding="utf-8")
    print(f"wrote {out} ({len(text)} bytes, {len(new_files)} new script(s))")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
