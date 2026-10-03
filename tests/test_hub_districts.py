"""Hub districts: the Volcano Forge, Frozen Temple and Sunset Dojo build cleanly, stay inside their budgets,
sit on their own levelled ground (no stray generic props on it) and animate through the same mover scheme as the Neon City."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game  # noqa: E402

MODS = "ServerScriptService/IronClashServer/Modules/"
DISTRICTS = {"VolcanoForge": "HubVolcano", "FrozenTemple": "HubFrozen", "SunsetDojo": "HubDojo"}


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


class HubDistricts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()
        cls.Hub = cls.g.module(MODS + "Hub")
        cls.Config = cls.g.module("ReplicatedStorage/Shared/Config")
        cls.O = cls.Config.Hub.origin
        cls.hub = cls.Hub.build()
        cls.out = cls.hub.FindFirstChild(cls.hub, "Outskirts")
        cls.mods = {name: cls.g.module(MODS + mod) for name, mod in DISTRICTS.items()}
        cls.pads = {name: cls.mods[name].pad for name in DISTRICTS}

    def model(self, name):
        m = self.out.FindFirstChild(self.out, name)
        self.assertIsNotNone(m, f"{name} was not built")
        return m

    def count(self, model):
        return sum(1 for d in lua_list(model.GetDescendants(model)) if d.IsA(d, "BasePart"))

    def test_builds_without_warnings(self):
        w = self.g.env.__warnings
        msgs = [w[k] for k in sorted(w.keys())] if w else []
        self.assertEqual(msgs, [])

    def test_districts_are_substantial_but_within_budget(self):
        for name in DISTRICTS:
            n = self.count(self.model(name))
            self.assertGreater(n, 1200, f"{name} looks thin ({n} parts)")
            self.assertLess(n, 6500, f"{name} is too heavy ({n} parts)")

    def test_every_part_is_sane_and_anchored(self):
        for name in DISTRICTS:
            for d in lua_list(self.model(name).GetDescendants(self.model(name))):
                if not d.IsA(d, "BasePart"):
                    continue
                p, s = d.CFrame.p, d.Size
                for c in (p.X, p.Y, p.Z, s.X, s.Y, s.Z):
                    self.assertFalse(math.isnan(c) or math.isinf(c), name)
                # Roblox clamps part sizes to a 0.05 minimum, which would silently change thin parts
                self.assertTrue(min(s.X, s.Y, s.Z) >= 0.05, f"{name}: part {d.Name} is thinner than 0.05 ({s.X:.3f}, {s.Y:.3f}, {s.Z:.3f})")
                self.assertTrue(d.Anchored, f"{name}: unanchored part")
                self.assertFalse(d.CanCollide, f"{name}: colliding scenery")

    def test_movers_follow_the_ambient_scheme(self):
        for name in DISTRICTS:
            movers = self.model(name).FindFirstChild(self.model(name), "Movers")
            self.assertIsNotNone(movers, f"{name} has no Movers")
            ms = lua_list(movers.GetChildren(movers))
            self.assertGreater(len(ms), 12, f"{name}: too few movers")
            for m in ms:
                self.assertTrue(m.GetAttribute(m, "Path"), f"{name}/{m.Name}: no Path")
                self.assertGreater(m.GetAttribute(m, "Speed"), 0)
                kind = m.GetAttribute(m, "Kind")
                self.assertIn(kind, ("walker", "cart", "glider"))
                self.assertTrue(any(d.GetAttribute(d, "Off") is not None for d in lua_list(m.GetDescendants(m)) if d.IsA(d, "BasePart")),
                                f"{name}/{m.Name}: parts carry no Off attribute")

    def test_no_generic_props_on_district_ground(self):
        """Props from the outskirts' scatter / set pieces must stay off the districts' levelled ground."""
        district_models = set(DISTRICTS) | {"NeonCity"}
        stray = []
        for child in lua_list(self.out.GetChildren(self.out)):
            if child.Name in district_models:
                continue
            for d in ([child] + lua_list(child.GetDescendants(child))):
                if not d.IsA(d, "BasePart"):
                    continue
                p = d.CFrame.p
                for name, pad in self.pads.items():
                    if pad(self.O, p.X, p.Z) > 0.5:
                        stray.append((name, d.Name, round(p.X - self.O.X), round(p.Z - self.O.Z)))
        self.assertLess(len(stray), 5, f"stray props on district ground: {stray[:12]}")

    def test_districts_do_not_overlap_each_other(self):
        """Big slabs (pavements, forecourts, plinths) of different districts must not overlap, or they z-fight."""
        def boxes(name):
            out = []
            for d in lua_list(self.model(name).GetDescendants(self.model(name))):
                if not d.IsA(d, "BasePart") or d.Size.X * d.Size.Z < 150:
                    continue
                cf, sz = d.CFrame, d.Size
                r = cf.r
                hx = abs(r[1]) * sz.X / 2 + abs(r[2]) * sz.Y / 2 + abs(r[3]) * sz.Z / 2
                hy = abs(r[4]) * sz.X / 2 + abs(r[5]) * sz.Y / 2 + abs(r[6]) * sz.Z / 2
                hz = abs(r[7]) * sz.X / 2 + abs(r[8]) * sz.Y / 2 + abs(r[9]) * sz.Z / 2
                out.append((cf.p.X - hx, cf.p.X + hx, cf.p.Y - hy, cf.p.Y + hy, cf.p.Z - hz, cf.p.Z + hz, d.Name))
            return out
        names = list(DISTRICTS) + ["NeonCity"]  # the city's pavements border the Volcano Forge and the Dojo
        clashes = []
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                for x0, x1, y0, y1, z0, z1, n1 in boxes(a):
                    for p0, p1, q0, q1, w0, w1, n2 in boxes(b):
                        if min(x1, p1) - max(x0, p0) > 1 and min(z1, w1) - max(z0, w0) > 1 and min(y1, q1) - max(y0, q0) > 0.05:
                            clashes.append((a, b, round((x0 + x1) / 2 - self.O.X), round((z0 + z1) / 2 - self.O.Z)))
        self.assertEqual(clashes[:8], [], f"{len(clashes)} overlapping slabs between districts")

    def test_plaza_wall_stays_clear(self):
        """Nothing a district builds may stand inside the plaza (radius 79) - that is the playable space."""
        for name in DISTRICTS:
            for d in lua_list(self.model(name).GetDescendants(self.model(name))):
                if not d.IsA(d, "BasePart"):
                    continue
                p = d.CFrame.p
                r = math.hypot(p.X - self.O.X, p.Z - self.O.Z)
                self.assertGreater(r + max(d.Size.X, d.Size.Z) / 2, 79 + 0.0, f"{name}/{d.Name} inside the plaza")
                self.assertGreater(r, 80.5, f"{name}/{d.Name} centre at r={r:.1f} is inside the plaza wall")


if __name__ == "__main__":
    unittest.main()
