#!/usr/bin/env python3
"""Render fighters / arenas from the game's own Lua into PNGs (geometry preview, see tools/render.py).

  python3 tools/preview.py fighter KAI out.png [state] [side|front|three] [palette]
  python3 tools/preview.py roster out.png [state]
  python3 tools/preview.py arena 1 out.png [view]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "tools"))

from harness import Game  # noqa: E402
from render import Scene, render  # noqa: E402
from PIL import Image  # noqa: E402


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


def dump(g, root, only=None):
    fn = g.lua.execute("return dofile(%r)" % str(ROOT / "tests" / "dump.lua"))
    res = fn(root, only)
    parts = []
    for p in lua_list(res):
        parts.append({
            "sh": p["sh"], "mesh": p["mesh"], "mat": p["mat"],
            "cf": [p["cf"][i] for i in range(1, 13)],
            "sz": [p["sz"][i] for i in range(1, 4)],
            "col": [p["col"][i] for i in range(1, 4)],
            "t": p["t"], "neon": p["neon"], "name": p["name"],
        })
    return parts


def posed_fighter(g, fid, palette=1, state="Idle", move=None, t=0.0, mt=0.0, extra=None, clock=0.3):
    FM = g.module("ReplicatedStorage/Shared/FighterModels")
    Rig = g.module("ReplicatedStorage/Shared/Rig")
    Poses = g.module("ReplicatedStorage/Shared/Poses")
    model = FM.build(fid, palette, fid)
    info = Rig.measure(model)
    st = g.lua.table_from({"state": state, "t": t, "move": move, "mt": mt, "vy": 0, "h": 0, "walk": 0, "variant": 0, "poseVar": 1})
    if extra:
        for k, v in extra.items():
            st[k] = v
    pose = Poses.evaluate(st, clock)
    cf = g.env.CFrame.new(0, info.hipCenter, 0)
    Rig.poseStatic(info, pose, cf)
    return model, info


def fighter_scene(g, fid, palette=1, **kw):
    model, info = posed_fighter(g, fid, palette, **kw)
    sc = Scene()
    for p in dump(g, model):
        if p["name"] == "HumanoidRootPart" or (p["t"] >= 0.95):
            continue
        sc.add(p)
    return sc


CAMS = {
    "side": ((-11.0, 3.4, 0.0), (0, 2.8, 0)),
    "front": ((0, 3.6, -11.0), (0, 2.8, 0)),
    "three": ((-7.0, 3.9, -8.5), (0, 2.75, 0)),
    "back": ((6.0, 3.9, 9.0), (0, 2.75, 0)),
    "close": ((-3.0, 4.6, -4.0), (0, 4.1, 0)),
}


def main():
    cmd = sys.argv[1]
    g = Game()
    if cmd == "fighter":
        fid, out = sys.argv[2], sys.argv[3]
        state = sys.argv[4] if len(sys.argv) > 4 else "Idle"
        view = sys.argv[5] if len(sys.argv) > 5 else "three"
        pal = int(sys.argv[6]) if len(sys.argv) > 6 else 1
        sc = fighter_scene(g, fid, pal, state=state)
        eye, tgt = CAMS[view]
        render(sc, eye, tgt, fov=34, size=(700, 800), bg=((40, 44, 70), (120, 124, 150))).save(out)
    elif cmd == "roster":
        out = sys.argv[2]
        state = sys.argv[3] if len(sys.argv) > 3 else "Idle"
        FM = g.module("ReplicatedStorage/Shared/FighterModels")
        tiles = []
        for f in lua_list(FM.ROSTER):
            sc = fighter_scene(g, f.id, 1, state=state)
            tiles.append(render(sc, *CAMS["three"], fov=34, size=(420, 560), bg=((40, 44, 70), (120, 124, 150))))
        W = Image.new("RGB", (420 * 3, 560 * 2))
        for i, t in enumerate(tiles):
            W.paste(t, ((i % 3) * 420, (i // 3) * 560))
        W.save(out)


if __name__ == "__main__":
    main()
