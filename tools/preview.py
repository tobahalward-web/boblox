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


TERRAIN_COL = {"Grass": (84, 130, 56), "Snow": (238, 243, 250), "Rock": (112, 106, 100), "Basalt": (56, 50, 50),
               "CrackedLava": (205, 72, 22), "Water": (46, 104, 168), "Glacier": (168, 208, 236), "Ground": (110, 90, 70)}


def arena_scene(g, index, with_terrain=True):
    """Build the stages with the real Arenas module and collect parts (+ terrain approximations)."""
    Arenas = g.module("ServerScriptService/IronClashServer/Modules/Arenas")
    Config = g.module("ReplicatedStorage/Shared/Config")
    lst = Arenas.build()
    model = g.env.workspace.FindFirstChild(g.env.workspace, "Arenas").FindFirstChild(g.env.workspace.FindFirstChild(g.env.workspace, "Arenas"), "Arena%d" % index)
    sc = Scene()
    parts = dump(g, model)
    for p in parts:
        sc.add(p)
    origin = Config.Arenas[index].origin
    if with_terrain:
        T = g.shim.Terrain
        calls = T.calls
        for i in range(1, len(calls) + 1):
            c = calls[i]
            fn = c[1]
            if fn == "FillBlock":
                cf, size, mat = c[2], c[3], c[4]
                if abs(cf.p.X - origin.X) > 600 or abs(cf.p.Z - origin.Z) > 600:
                    continue
                mname = mat.Name if mat else "Grass"
                if mname == "Air":
                    continue
                sc.add({"sh": "Block", "mesh": None, "cf": [cf.p.X, cf.p.Y, cf.p.Z] + [cf.r[k] for k in range(1, 10)],
                        "sz": [size.X, size.Y, size.Z], "col": list(TERRAIN_COL.get(mname, (100, 100, 100))), "t": 0, "neon": False})
            elif fn == "WriteVoxels":
                region, res, mats, occ = c[2], c[3], c[4], c[5]
                cols = g.lua.execute("""
                    return function(region, res, mats, occ, step)
                        local out = {}
                        local x0, y0, z0 = region[1].X, region[1].Y, region[1].Z
                        local nx = #occ
                        for i = 1, nx, step do
                            local ny = #occ[i]
                            local nz = #occ[i][1]
                            for k = 1, nz, step do
                                local top = nil
                                for j = ny, 1, -1 do
                                    if occ[i][j][k] > 0.5 then top = j break end
                                end
                                if top then
                                    out[#out + 1] = { x0 + (i - 0.5) * res, y0 + top * res, z0 + (k - 0.5) * res, tostring(mats[i][top][k].Name) }
                                end
                            end
                        end
                        return out
                    end""")(region, res, mats, occ, 2)
                for j in range(1, len(cols) + 1):
                    col = cols[j]
                    x, ytop, z, mname = col[1], col[2], col[3], col[4]
                    base = origin.Y - 60
                    hgt = max(1.0, ytop - base)
                    sc.add({"sh": "Block", "mesh": None, "cf": [x, base + hgt / 2, z, 1, 0, 0, 0, 1, 0, 0, 0, 1],
                            "sz": [8, hgt, 8], "col": list(TERRAIN_COL.get(mname, (100, 100, 100))), "t": 0, "neon": False})
            elif fn == "FillBall":
                center, radius, mat = c[2], c[3], c[4]
                if abs(center.X - origin.X) > 600 or abs(center.Z - origin.Z) > 600:
                    continue
                mname = mat.Name if mat else "Grass"
                sc.add({"sh": "Ball", "mesh": "Sphere", "cf": [center.X, center.Y, center.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1],
                        "sz": [radius * 2, radius * 1.4, radius * 2], "col": list(TERRAIN_COL.get(mname, (100, 100, 100))), "t": 0, "neon": mname == "CrackedLava"})
    return sc, origin


ARENA_VIEWS = {
    # in-game match camera: side view from +Z looking toward -Z, 50 degree vertical FOV
    "game": lambda o: ((o.X, o.Y + 4.9, o.Z + 15.5), (o.X, o.Y + 2.8, o.Z), 50, (1000, 560)),
    "gameL": lambda o: ((o.X - 30, o.Y + 6, o.Z + 14), (o.X - 4, o.Y + 3, o.Z - 6), 50, (1000, 560)),
    "wide": lambda o: ((o.X + 40, o.Y + 30, o.Z + 95), (o.X, o.Y + 8, o.Z - 20), 55, (1000, 560)),
    "top": lambda o: ((o.X + 1, o.Y + 150, o.Z + 60), (o.X, o.Y - 5, o.Z), 50, (1000, 700)),
    "corner": lambda o: ((o.X + 14, o.Y + 6, o.Z + 14), (o.X + 24, o.Y + 2, o.Z + 24), 45, (1000, 560)),
    "hall": lambda o: ((o.X - 18, o.Y + 6, o.Z - 62), (o.X, o.Y + 7, o.Z - 100), 55, (1000, 560)),
    "gate": lambda o: ((o.X - 10, o.Y + 4, o.Z - 40), (o.X, o.Y + 7, o.Z - 66), 55, (1000, 560)),
    "ringcorner": lambda o: ((o.X + 12, o.Y + 5, o.Z + 12), (o.X + 25, o.Y + 2.5, o.Z + 25), 50, (1000, 560)),
    "fort": lambda o: ((o.X - 20, o.Y + 6, o.Z - 40), (o.X, o.Y + 6, o.Z - 112), 60, (1000, 560)),
    "temple": lambda o: ((o.X - 24, o.Y + 7, o.Z - 50), (o.X, o.Y + 9, o.Z - 104), 58, (1000, 560)),
    "back": lambda o: ((o.X, o.Y + 8, o.Z - 6), (o.X, o.Y + 14, o.Z - 90), 60, (1000, 560)),
}

SKY = {1: ((8, 6, 24), (60, 40, 90)), 2: ((70, 60, 110), (240, 170, 110)), 3: ((30, 12, 10), (130, 50, 25)), 4: ((50, 70, 110), (190, 215, 240))}


def main():
    cmd = sys.argv[1]
    g = Game()
    if cmd == "arena":
        idx = int(sys.argv[2])
        out = sys.argv[3]
        views = sys.argv[4].split(",") if len(sys.argv) > 4 else ["game"]
        sc, o = arena_scene(g, idx)
        ims = []
        for v in views:
            eye, tgt, fov, size = ARENA_VIEWS[v](o)
            ims.append(render(sc, eye, tgt, fov=fov, size=size, bg=SKY[idx], fog=(120, 600, tuple(SKY[idx][1])), ss=2))
        if len(ims) == 1:
            ims[0].save(out)
        else:
            Wd = max(i.size[0] for i in ims)
            Ht = sum(i.size[1] for i in ims)
            canvas = Image.new("RGB", (Wd, Ht))
            y = 0
            for i in ims:
                canvas.paste(i, (0, y))
                y += i.size[1]
            canvas.save(out)
        return
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
