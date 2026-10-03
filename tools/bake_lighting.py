#!/usr/bin/env python3
"""Write the hub's sky (Themes.Presets.Hub, chosen by Config.Hub.sky) into the place template's saved Lighting,
so Studio shows the same look in edit mode (before Play) that the client applies at runtime.

  python3 tools/bake_lighting.py            # edits IronClash/place.rbxlx.tmpl in place
  python3 tools/build.py IronClash IronClash_6.rbxlx
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
from harness import Game  # noqa: E402

TMPL = ROOT / "IronClash" / "place.rbxlx.tmpl"


def block(text, marker, fn):
    """Apply fn to the whole <Item ...>...</Item> that starts at the first `marker`."""
    start = text.index(marker)
    depth = 0
    for m in re.finditer(r"<Item |</Item>", text[start:]):
        depth += 1 if m.group(0) == "<Item " else -1
        if depth == 0:
            end = start + m.end()
            break
    return text[:start] + fn(text[start:end]) + text[end:]


def set_color(b, name, c):
    pat = r'(<Color3 name="%s">\s*<R>)[^<]*(</R>\s*<G>)[^<]*(</G>\s*<B>)[^<]*(</B>)' % name
    assert re.search(pat, b), name
    return re.sub(pat, lambda m: m.group(1) + repr(round(c.R, 9)) + m.group(2) + repr(round(c.G, 9)) + m.group(3) + repr(round(c.B, 9)) + m.group(4), b, count=1)


def set_num(b, tag, name, v):
    pat = r'(<%s name="%s">)[^<]*(</%s>)' % (tag, name, tag)
    assert re.search(pat, b), name
    return re.sub(pat, lambda m: m.group(1) + str(v) + m.group(2), b, count=1)


def main():
    g = Game()
    themes = g.module("StarterPlayer/StarterPlayerScripts/IronClashClient/Themes")
    p = themes.Presets.Hub
    text = TMPL.read_text(encoding="utf-8")

    def lighting(b):
        k = b.index('<Item class="Sky"')  # the Lighting item's own properties come before its first child
        head, rest = b[:k], b[k:]
        for n in ("Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom"):
            head = set_color(head, n, p[n])
        for n in ("Brightness", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation", "GeographicLatitude"):
            head = set_num(head, "float", n, round(p[n], 6))
        ct = p.ClockTime
        h, m, s = int(ct), int((ct % 1) * 60), round((((ct % 1) * 60) % 1) * 60)
        head = set_num(head, "string", "TimeOfDay", f"{h:02d}:{m:02d}:{s:02d}")
        return head + rest

    text = block(text, '<Item class="Lighting"', lighting)

    def props(b, tbl, floats, colors, ints=()):
        for n in floats:
            b = set_num(b, "float", n, round(tbl[n], 6))
        for n in ints:
            b = set_num(b, "int", n, int(tbl[n]))
        for n in colors:
            b = set_color(b, n, tbl[n])
        return b

    text = block(text, '<Item class="Sky"', lambda b: props(b, p.Sky, ("SunAngularSize", "MoonAngularSize"), (), ("StarCount",)))
    text = block(text, '<Item class="Atmosphere"', lambda b: props(b, p.Atmosphere, ("Density", "Offset", "Glare", "Haze"), ("Color", "Decay")))
    text = block(text, '<Item class="BloomEffect"', lambda b: props(b, p.Bloom, ("Intensity", "Size", "Threshold"), ()))
    text = block(text, '<Item class="ColorCorrectionEffect"', lambda b: props(b, p.CC, ("Brightness", "Contrast", "Saturation"), ("TintColor",)))
    text = block(text, '<Item class="SunRaysEffect"', lambda b: props(b, p.SunRays, ("Intensity", "Spread"), ()))
    text = block(text, '<Item class="DepthOfFieldEffect"', lambda b: props(b, p.DOF, ("FarIntensity", "NearIntensity", "InFocusRadius"), ()))
    text = block(text, '<Item class="Clouds"', lambda b: props(b, p.Clouds, ("Cover", "Density"), ("Color",)))
    TMPL.write_text(text, encoding="utf-8")
    print("baked the hub sky (%s) into %s" % (g.module("ReplicatedStorage/Shared/Config").Hub.sky, TMPL.relative_to(ROOT)))


if __name__ == "__main__":
    main()
