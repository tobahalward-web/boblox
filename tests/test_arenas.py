"""Arena stage tests: clean builds, budgets, a clear fighting zone, and no coplanar (z-fighting) top faces."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ARENAS = "ServerScriptService/IronClashServer/Modules/Arenas"


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


def top_of(p):
    """World-space top of a part's bounding box (rotation aware)."""
    R = p["R"]
    sx, sy, sz = p["size"]
    if p["shape"] == "Ball":
        return p["pos"][1] + sx / 2
    return p["pos"][1] + abs(R[3]) * sx / 2 + abs(R[4]) * sy / 2 + abs(R[5]) * sz / 2


def collect(g, model):
    """Return part descriptors for everything under `model` (one Lua pass)."""
    fn = g.lua.execute("""
        return function(root)
            local out, lights, emitters = {}, 0, 0
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("BasePart") then
                    local cf, sz = d.CFrame, d.Size
                    out[#out + 1] = { cf.p.X, cf.p.Y, cf.p.Z, cf.r[1], cf.r[2], cf.r[3], cf.r[4], cf.r[5], cf.r[6], cf.r[7], cf.r[8], cf.r[9],
                        sz.X, sz.Y, sz.Z, d.Shape and d.Shape.Name or "Block", d.Transparency or 0, d.CanCollide and 1 or 0, d.Anchored and 1 or 0,
                        d.Material and d.Material.Name or "", d.ClassName }
                elseif d:IsA("Light") then
                    lights = lights + 1
                elseif d.ClassName == "ParticleEmitter" or d.ClassName == "Fire" then
                    emitters = emitters + 1
                end
            end
            return out, lights, emitters
        end""")
    parts, lights, emitters = fn(model)
    res = []
    for i in range(1, len(parts) + 1):
        p = parts[i]
        v = [p[k] for k in range(1, 22)]
        res.append({
            "pos": v[0:3], "R": v[3:12], "size": v[12:15], "shape": v[15], "t": v[16], "collide": v[17], "anchored": v[18],
            "mat": v[19], "cls": v[20],
        })
    return res, lights, emitters


class ArenaBuilds(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()
        cls.arenas = cls.g.module(ARENAS)
        cls.list = lua_list(cls.arenas.build())
        cls.Config = cls.g.module("ReplicatedStorage/Shared/Config")
        root = cls.g.env.workspace.FindFirstChild(cls.g.env.workspace, "Arenas")
        cls.data = {}
        for i in range(1, 5):
            m = root.FindFirstChild(root, "Arena%d" % i)
            cls.data[i] = collect(cls.g, m)

    def origin(self, i):
        o = self.Config.Arenas[i].origin
        return o.X, o.Y, o.Z

    def test_builds_without_warnings(self):
        w = self.g.env.__warnings
        msgs = [w[k] for k in sorted(w.keys())] if w else []
        self.assertEqual(msgs, [])

    def test_all_four_stages_have_content(self):
        for i in range(1, 5):
            parts, lights, emitters = self.data[i]
            self.assertGreater(len(parts), 1000, f"stage {i} looks empty ({len(parts)} parts)")

    def test_budgets(self):
        for i in range(1, 5):
            parts, lights, emitters = self.data[i]
            self.assertLess(len(parts), 9000, f"stage {i}: {len(parts)} parts")
            self.assertLess(lights, 70, f"stage {i}: {lights} lights")
            self.assertLess(emitters, 60, f"stage {i}: {emitters} emitters")

    def test_every_part_is_sane(self):
        for i in range(1, 5):
            for p in self.data[i][0]:
                for c in p["pos"] + p["size"]:
                    self.assertFalse(math.isnan(c) or math.isinf(c), f"stage {i}")
                self.assertTrue(all(s > 0 for s in p["size"]), f"stage {i}: zero-size part {p['size']}")
                self.assertEqual(p["anchored"], 1, f"stage {i}: unanchored part")

    def test_only_the_fighting_floor_collides(self):
        for i in range(1, 5):
            ox, oy, oz = self.origin(i)
            for p in self.data[i][0]:
                if p["collide"]:
                    # colliding parts are the floor slab pieces: top at the arena origin and inside the deck footprint
                    top = top_of(p)
                    self.assertAlmostEqual(top, oy, delta=0.1, msg=f"stage {i}: colliding part at y={top - oy:.2f}")

    def test_fighting_zone_is_clear(self):
        """Nothing solid may poke above the floor inside the area fighters can stand on."""
        for i in range(1, 5):
            ox, oy, oz = self.origin(i)
            for p in self.data[i][0]:
                if p["t"] > 0.5:
                    continue
                x, y, z = p["pos"]
                R = p["R"]
                sx, sy, sz = p["size"]
                # world-space half extents of the part's bounding box
                ex = abs(R[0]) * sx / 2 + abs(R[1]) * sy / 2 + abs(R[2]) * sz / 2
                ey = abs(R[3]) * sx / 2 + abs(R[4]) * sy / 2 + abs(R[5]) * sz / 2
                ez = abs(R[6]) * sx / 2 + abs(R[7]) * sy / 2 + abs(R[8]) * sz / 2
                inside = abs(x - ox) < 22 + ex and abs(z - oz) < 22 + ez
                if p["shape"] == "Ball":
                    ex = ey = ez = sx / 2
                if inside and (y - ey) < oy + 1.5 and (y + ey) > oy + 0.5:
                    # floor markings are allowed up to 0.2 above the floor
                    self.assertLess(y + ey, oy + 0.35, f"stage {i}: part at ({x - ox:.1f},{y - oy:.1f},{z - oz:.1f}) size {p['size']} sticks into the fighting zone")

    def test_no_coplanar_top_faces(self):
        """Two overlapping faces at the same height flicker (z-fight) as the camera moves."""
        for i in range(1, 5):
            faces = []
            for p in self.data[i][0]:
                if p["t"] > 0.5 or p["cls"] != "Part":
                    continue
                R = p["R"]
                x, y, z = p["pos"]
                sx, sy, sz = p["size"]
                if p["shape"] == "Block" and abs(R[4]) > 0.999 and abs(abs(R[0]) + abs(R[2]) - 1) < 1e-3 and (abs(R[0]) < 1e-3 or abs(R[0]) > 1 - 1e-3):
                    ex, ez = (sx / 2, sz / 2) if abs(R[0]) > 0.5 else (sz / 2, sx / 2)
                    faces.append((y + sy / 2, "rect", x - ex, x + ex, z - ez, z + ez, p))
                elif p["shape"] == "Cylinder" and abs(abs(R[3]) - 1) < 1e-3:
                    faces.append((y + sx / 2, "disc", x, z, sy / 2, 0, p))
            faces.sort(key=lambda f: f[0])
            clashes = []
            for a in range(len(faces)):
                for b in range(a + 1, len(faces)):
                    if faces[b][0] - faces[a][0] > 0.004:
                        break
                    if self._overlap(faces[a], faces[b]):
                        clashes.append((faces[a][0], faces[a][1], faces[b][1], faces[a][2:6], faces[b][2:6]))
            self.assertEqual(clashes[:5], [], f"stage {i}: {len(clashes)} coplanar overlapping top faces")

    @staticmethod
    def _overlap(a, b):
        if a[1] == "rect" and b[1] == "rect":
            return min(a[3], b[3]) - max(a[2], b[2]) > 0.05 and min(a[5], b[5]) - max(a[4], b[4]) > 0.05
        if a[1] == "disc" and b[1] == "disc":
            return math.hypot(a[2] - b[2], a[3] - b[3]) < a[4] + b[4] - 0.05
        d, r = (a, b) if a[1] == "disc" else (b, a)
        cx, cz, rad = d[2], d[3], d[4]
        nx = min(max(cx, r[2]), r[3])
        nz = min(max(cz, r[4]), r[5])
        return math.hypot(cx - nx, cz - nz) < rad - 0.05

    def test_stages_are_deterministic(self):
        g2 = Game()
        arenas2 = g2.module(ARENAS)
        arenas2.build()
        root = g2.env.workspace.FindFirstChild(g2.env.workspace, "Arenas")
        for i in range(1, 5):
            parts, _, _ = collect(g2, root.FindFirstChild(root, "Arena%d" % i))
            self.assertEqual(len(parts), len(self.data[i][0]))

    def test_rebuild_is_idempotent(self):
        before = {i: len(self.data[i][0]) for i in range(1, 5)}
        self.arenas.build()  # models carry the current BuildVersion, so nothing is rebuilt
        root = self.g.env.workspace.FindFirstChild(self.g.env.workspace, "Arenas")
        for i in range(1, 5):
            parts, _, _ = collect(self.g, root.FindFirstChild(root, "Arena%d" % i))
            self.assertEqual(len(parts), before[i])


if __name__ == "__main__":
    unittest.main()
