#!/usr/bin/env python3
"""Render the hub's districts from the game's own Lua (geometry preview, see tools/render.py).

  python3 tools/preview_hub.py out.png volcano|frozen|dojo|city [view ...]

Views are named camera presets standing on the plaza wall looking out at a district (or a close-up).
Not a Studio render: no lighting, materials, particles or post-processing.
"""
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "tools"))

from harness import Game  # noqa: E402
from preview import dump, lua_list  # noqa: E402
from render import Scene, render  # noqa: E402
from PIL import Image  # noqa: E402

ANGLE = {"volcano": 0.0, "frozen": math.pi / 2, "dojo": math.pi, "city": -math.pi / 2}
SKY = {"volcano": ((40, 22, 20), (150, 80, 50)), "frozen": ((60, 80, 130), (200, 220, 245)),
       "dojo": ((70, 60, 110), (240, 170, 110)), "city": ((8, 6, 24), (60, 40, 90))}
TERRAIN_COL = {"Grass": (84, 130, 56), "LeafyGrass": (70, 118, 52), "Snow": (238, 243, 250), "Rock": (112, 106, 100), "Basalt": (56, 50, 50),
               "CrackedLava": (205, 72, 22), "Water": (46, 104, 168), "Glacier": (168, 208, 236), "Ground": (110, 90, 70),
               "Ice": (160, 205, 235), "Mud": (80, 62, 48), "Pavement": (110, 110, 120), "Asphalt": (50, 50, 58)}


def view_for(kind, name, O):
    a = ANGLE[kind]
    out = (math.cos(a), math.sin(a))
    right = (-math.sin(a), math.cos(a))

    def at(u, y, v):
        return (O.X + out[0] * v + right[0] * u, O.Y + y, O.Z + out[1] * v + right[1] * u)

    V = {
        # standing on the plaza wall at the district's gate, looking straight down the avenue
        # what a player sees from the plaza: standing by the fountain side of the district's station
        "plaza": (at(0, 7, 52), at(0, 22, 200), 70, (1200, 600)),
        "stairs": (at(0, 12, 190), at(0, 16, 236), 62, (1100, 600)),
        "gate": (at(0, 12, 70), at(0, 14, 200), 62, (1100, 600)),
        "left": (at(-40, 14, 74), at(40, 18, 180), 62, (1100, 600)),
        "right": (at(40, 14, 74), at(-40, 18, 180), 62, (1100, 600)),
        "wide": (at(0, 90, 40), at(0, 0, 190), 62, (1100, 650)),
        "top": (at(0, 330, 100), at(0, 0, 172), 55, (1000, 800)),
        "near": (at(-26, 10, 90), at(10, 8, 128), 62, (1100, 600)),
        "mid": (at(30, 14, 140), at(-6, 10, 192), 62, (1100, 600)),
        "far": (at(0, 22, 175), at(0, 24, 250), 62, (1100, 600)),
        "back": (at(60, 40, 120), at(-20, 26, 230), 62, (1100, 600)),
    }
    return V[name]


def terrain_parts(g, centre, radius):
    T = g.shim.Terrain
    calls = T.calls
    out = []
    for i in range(1, len(calls) + 1):
        c = calls[i]
        if c[1] != "WriteVoxels":
            continue
        region, res, mats, occ = c[2], c[3], c[4], c[5]
        cols = g.lua.execute("""
            return function(region, res, mats, occ, step, cx, cz, rad)
                local out = {}
                local x0, y0, z0 = region[1].X, region[1].Y, region[1].Z
                local nx = #occ
                for i = 1, nx, step do
                    local ny = #occ[i]
                    local nz = #occ[i][1]
                    for k = 1, nz, step do
                        local x, z = x0 + (i - 0.5) * res, z0 + (k - 0.5) * res
                        if (x - cx) ^ 2 + (z - cz) ^ 2 < rad * rad then
                            local top = nil
                            for j = ny, 1, -1 do
                                if occ[i][j][k] > 0.5 then top = j break end
                            end
                            if top then
                                out[#out + 1] = { x, y0 + top * res, z, tostring(mats[i][top][k].Name) }
                            end
                        end
                    end
                end
                return out
            end""")(region, res, mats, occ, 2, centre[0], centre[2], radius)
        for j in range(1, len(cols) + 1):
            col = cols[j]
            out.append((col[1], col[2], col[3], col[4]))
    return out


def main():
    out_png, kind = sys.argv[1], sys.argv[2]
    views = sys.argv[3:] or ["gate"]
    g = Game()
    H = g.module("ServerScriptService/IronClashServer/Modules/Hub")
    Config = g.module("ReplicatedStorage/Shared/Config")
    O = Config.Hub.origin
    hub = H.build()
    # the terrain is written by a background task that yields every couple of chunks: run it to the end
    g.lua.eval("function(env) for _, co in ipairs(env.__tasks) do local n = 0 while coroutine.status(co) == 'suspended' and n < 400 do coroutine.resume(co) n = n + 1 end end end")(g.env)
    ims = []
    for vname in views:
        eye, tgt, fov, size = view_for(kind, vname, O)
        # only the parts within reach of the view
        cx, cz = (eye[0] + tgt[0]) / 2, (eye[2] + tgt[2]) / 2
        reach = 330
        fn = g.lua.execute("""return function(root, cx, cz, r)
            local only = {}
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("BasePart") then
                    local p = d.CFrame.p
                    if (p.X - cx) ^ 2 + (p.Z - cz) ^ 2 < r * r then only[#only + 1] = d end
                end
            end
            return only
        end""")
        only = fn(hub.FindFirstChild(hub, "Outskirts"), cx, cz, reach)
        sc = Scene()
        fn2 = g.lua.execute("return dofile(%r)" % str(ROOT / "tests" / "dump.lua"))
        for p in lua_list(fn2(hub, only)):
            if p["t"] >= 0.95:
                continue
            sc.add({"sh": p["sh"], "mesh": p["mesh"], "mat": p["mat"], "cf": [p["cf"][i] for i in range(1, 13)],
                    "sz": [p["sz"][i] for i in range(1, 4)], "col": [p["col"][i] for i in range(1, 4)], "t": p["t"], "neon": p["neon"], "name": p["name"]})
        for (x, y, z, mname) in terrain_parts(g, (cx, 0, cz), reach):
            base = O.Y - 40
            sc.add({"sh": "Block", "mesh": None, "cf": [x, base + (y - base) / 2, z, 1, 0, 0, 0, 1, 0, 0, 0, 1], "sz": [8, y - base, 8],
                    "col": list(TERRAIN_COL.get(mname, (100, 100, 100))), "t": 0, "neon": False})
        ims.append(render(sc, eye, tgt, fov=fov, size=size, bg=SKY[kind], fog=(160, 700, tuple(SKY[kind][1])), ss=1))
        print("rendered", vname, flush=True)
    if len(ims) == 1:
        ims[0].save(out_png)
    else:
        w = max(i.size[0] for i in ims)
        canvas = Image.new("RGB", (w, sum(i.size[1] for i in ims)))
        y = 0
        for i in ims:
            canvas.paste(i, (0, y))
            y += i.size[1]
        canvas.save(out_png)


if __name__ == "__main__":
    main()
