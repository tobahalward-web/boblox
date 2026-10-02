#!/usr/bin/env python3
"""Pull the fighter body models out of a place file into IronClash/assets/FighterAssets.xml.

  python3 tools/import_assets.py <place.rbxlx> [IronClash/assets/FighterAssets.xml]

Each model is cleaned (scripts, sounds, joints of R6 bodies, stray helper objects are dropped) and
repackaged as a Model named by its fighter slot. tools/build.py inserts the result under
ReplicatedStorage/FighterAssets. At run time Shared/ImportedFighters rebuilds the rig around the parts.
"""
import copy
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

DROP = {"Script", "LocalScript", "ModuleScript", "Sound", "Camera", "StringValue", "BoolValue", "IntValue",
        "NumberValue", "Fire", "Smoke", "Sparkles", "Snap", "Glue", "ForceField", "Animator", "ParticleEmitter", "Folder"}
R6_DROP = {"Motor6D", "Weld", "WeldConstraint", "Humanoid", "ManualWeld"}

# source model (name in Workspace, or a predicate) -> asset name
SOURCES = {
    "NARUTO": ("Naruto Shippuden", "inner"),
    "GOKU": (" Goku", "goku"),
    "GOJO": ("gojo", "model"),
    "SUKUNA": ("Sukuna", "model"),
    "LUFFY": ("HINTOX_YT", "r15"),
}


def name_of(e):
    n = e.find('Properties/string[@name="Name"]')
    return (n.text or "") if n is not None else ""


def clean(item, r6):
    for ch in list(item.findall("Item")):
        cls = ch.get("class")
        if cls in DROP or (r6 and cls in R6_DROP):
            item.remove(ch)
        else:
            clean(ch, r6)


def new_model(name, referent):
    it = ET.Element("Item", {"class": "Model", "referent": referent})
    props = ET.SubElement(it, "Properties")
    n = ET.SubElement(props, "string", {"name": "Name"})
    n.text = name
    return it


def find_model(ws, nm):
    for it in ws.iter("Item"):
        if name_of(it) == nm and it.get("class") in ("Model",):
            return it
    return None


def main(src, out):
    root = ET.parse(src).getroot()
    ws = [c for c in root.findall("Item") if c.get("class") == "Workspace"][0]
    folder = ET.Element("Item", {"class": "Folder", "referent": "RBXFIGHTERASSETS00000000000000000001"})
    fp = ET.SubElement(folder, "Properties")
    ET.SubElement(fp, "string", {"name": "Name"}).text = "FighterAssets"
    for key, (nm, kind) in SOURCES.items():
        m = find_model(ws, nm)
        if m is None:
            raise SystemExit(f"model '{nm}' not found in {src}")
        r6 = kind != "r15"
        ref = "RBXFIGHTERASSET%016X" % (len(folder) + 1)
        if kind == "inner":  # Naruto: the real model is nested one level down
            inner = [c for c in m.findall("Item") if c.get("class") == "Model"][0]
            asset = new_model(key, ref)
            for c in inner.findall("Item"):
                asset.append(copy.deepcopy(c))
        elif kind == "goku":
            asset = new_model(key, ref)
            for c in m.findall("Item"):
                asset.append(copy.deepcopy(c))
            parent = None
            for it in ws.iter("Item"):
                if it is not m and any(c is m for c in it.findall("Item")):
                    parent = it
            for c in parent.findall("Item") if parent is not None else []:
                if c.get("class") == "MeshPart" and "Hair" in name_of(c):
                    asset.append(copy.deepcopy(c))
        else:
            asset = copy.deepcopy(m)
            asset.set("referent", ref)
        # root name
        n = asset.find('Properties/string[@name="Name"]')
        n.text = key
        clean(asset, r6)
        folder.append(asset)
        parts = [d for d in asset.iter("Item") if d.get("class") in ("Part", "MeshPart", "UnionOperation")]
        print(f"{key:7s} {'R6 ' if r6 else 'R15'} parts={len(parts):3d}  {[name_of(p) for p in parts][:14]}")
    ET.ElementTree(folder).write(out, encoding="utf-8", xml_declaration=False)
    # Items refer to shared strings (tags, attributes) by md5; their data lives in a <SharedStrings>
    # section at the end of the file, which must travel with the models or Studio refuses to open the place.
    needed = {e.text for e in folder.iter("SharedString") if e.text}
    table = {e.get("md5"): e for e in (root.find("SharedStrings") or [])}
    missing = needed - set(table)
    if missing:
        raise SystemExit(f"shared strings not defined in the source file: {sorted(missing)[:3]}")
    side = Path(out).with_name("FighterAssets.sharedstrings.xml")
    with open(side, "w", encoding="utf-8") as f:
        for md5 in sorted(needed):
            f.write(ET.tostring(table[md5], encoding="unicode").strip() + "\n")
    print(f"wrote {side} ({len(needed)} shared strings)")
    print("wrote", out, Path(out).stat().st_size, "bytes")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "IronClash/assets/FighterAssets.xml")
