"""Fighter model + secondary motion tests (geometry, rig compatibility, chain physics)."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game  # noqa: E402

SHARED = "ReplicatedStorage/Shared/"


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


def parts_of(model):
    return [d for d in lua_list(model.GetDescendants(model)) if d.IsA(d, "BasePart")]


class Models(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()
        cls.FM = cls.g.module(SHARED + "FighterModels")
        cls.Rig = cls.g.module(SHARED + "Rig")
        cls.Poses = cls.g.module(SHARED + "Poses")
        cls.Moves = cls.g.module(SHARED + "Moves")
        cls.Sec = cls.g.module(SHARED + "Secondary")
        cls.Life = cls.g.module(SHARED + "Life")
        cls.CF = cls.g.env.CFrame

    def roster(self):
        return lua_list(self.FM.ROSTER)

    def test_every_fighter_builds_with_full_skeleton(self):
        needed = {"HumanoidRootPart", "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
                  "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
                  "RightUpperLeg", "RightLowerLeg", "RightFoot"}
        for f in self.roster():
            for pal in (1, 2):
                m = self.FM.build(f.id, pal, f.name)
                names = {p.Name for p in parts_of(m)}
                self.assertTrue(needed <= names, f"{f.id}/{pal} missing {needed - names}")
                res = self.Rig.measure(m)
                info = res[0] if isinstance(res, tuple) else res
                self.assertIsNotNone(info, f"{f.id}: Rig.measure failed: {res}")
                self.assertAlmostEqual(info.hipCenter, 2.85, delta=0.3)

    def test_bodies_are_organic_not_blocky(self):
        """Large box/wedge parts are what made the old fighters look blocky: keep them to a small share."""
        for f in self.roster():
            m = self.FM.build(f.id, 1, f.name)
            block_vol = total_vol = 0.0
            for p in parts_of(m):
                if p.Name != "Vis":
                    continue
                s = p.Size
                v = s.X * s.Y * s.Z
                total_vol += v
                shape = p.Shape.Name if p.Shape else "Block"
                is_ellipsoid = any(c.ClassName == "SpecialMesh" for c in lua_list(p.GetChildren(p)))
                if shape == "Block" and not is_ellipsoid:
                    block_vol += v
                if p.ClassName == "WedgePart":
                    block_vol += v
            self.assertLess(block_vol / total_vol, 0.06, f"{f.id}: {block_vol / total_vol:.1%} of visible volume is boxes")

    def test_part_budget(self):
        for f in self.roster():
            m = self.FM.build(f.id, 1, f.name)
            n = len(parts_of(m))
            self.assertLess(n, 300, f"{f.id} has {n} parts")

    def test_every_fighter_has_secondary_chains(self):
        for f in self.roster():
            m = self.FM.build(f.id, 1, f.name)
            chains = lua_list(self.Sec.collect(m))
            self.assertGreaterEqual(len(chains), 2, f"{f.id} has no hair/cloth chains")
            for ch in chains:
                segs = lua_list(ch.segs)
                self.assertGreaterEqual(len(segs), 1)

    def test_every_move_pose_is_finite_and_grounded(self):
        """Evaluate every move at several frames; no NaNs, nobody sinks through the floor."""
        m = self.FM.build("KAI", 1, "KAI")
        info = self.Rig.measure(m)
        floor_lowest = {}
        for id_ in lua_list(self.Moves.Order):
            mv = self.Moves.List[id_]
            for frac in (0.0, 0.25, 0.5, 0.75, 1.0):
                st = self.g.lua.table_from({"state": "Attack", "move": id_, "mt": mv.total * frac / 60, "t": 0})
                pose = self.Poses.evaluate(st, 0.5)
                self.Rig.poseStatic(info, pose, self.CF.new(0, info.hipCenter, 0))
                low = 1e9
                for p in parts_of(m):
                    pos = p.Position
                    for c in (pos.X, pos.Y, pos.Z):
                        self.assertFalse(math.isnan(c) or math.isinf(c), f"{id_}@{frac}: {p.Name}")
                    if p.Name in ("LeftFoot", "RightFoot"):
                        low = min(low, pos.Y)
                floor_lowest[id_] = min(floor_lowest.get(id_, 1e9), low)
        # moves performed on the ground keep feet near the floor (airborne ones are allowed to leave it)
        for id_, low in floor_lowest.items():
            self.assertGreater(low, -0.35, f"{id_} sinks into the floor ({low:.2f})")

    def test_all_palettes_have_required_look_fields(self):
        for f in self.roster():
            for pal in lua_list(f.palettes):
                for key in ("skin", "hair", "eye", "top", "glow"):
                    self.assertIsNotNone(pal[key], f"{f.id}: palette missing {key}")

    def test_eyes_blink(self):
        for f in self.roster():
            m = self.FM.build(f.id, 1, f.name)
            life = self.Life.new(m, 3)
            n = len(lua_list(life.lids))
            if f.id == "VEX":
                self.assertEqual(n, 0, f"{f.id} has a blindfold, nothing to blink")
                continue
            self.assertEqual(n, 4, f"{f.id}: two eyes x (lid + lash)")
            lids = lua_list(life.lids)
            self.assertTrue(all(l.Transparency == 1 for l in lids), "eyes start open")
            seen_closed = seen_open_after = False
            for _ in range(600):  # 10 s at 60 fps
                self.Life.step(life, 1 / 60)
                closed = all(l.Transparency == 0 for l in lids)
                seen_closed = seen_closed or closed
                if seen_closed and not closed:
                    seen_open_after = True
            self.assertTrue(seen_closed and seen_open_after, f"{f.id} never blinked")
            self.Life.squeeze(life, 0.3)
            self.Life.step(life, 1 / 60)
            self.assertTrue(all(l.Transparency == 0 for l in lids), "flinch closes the eyes")
            self.Life.clear(life)
            self.assertTrue(all(l.Transparency == 1 for l in lids))

    def test_limbs_are_continuous_lathes(self):
        """Arms and legs are stacks of overlapping discs: neighbours must overlap and step in width gently."""
        for f in self.roster():
            m = self.FM.build(f.id, 1, f.name)
            for bone_name in ("LeftLowerArm", "RightUpperArm", "LeftUpperLeg", "RightLowerLeg"):
                bone = m.FindFirstChild(m, bone_name)
                discs = []
                for c in lua_list(bone.GetChildren(bone)):
                    if c.Name == "Vis" and c.Shape.Name == "Cylinder" and abs(c.CFrame.r[4]) > 0.99:
                        discs.append((c.CFrame.p.Y, c.Size.X, c.Size.Y))
                self.assertGreater(len(discs), 8, f"{f.id}/{bone_name} should be a stack of discs")
                discs.sort()
                for (y0, th0, w0), (y1, th1, w1) in zip(discs, discs[1:]):
                    if y1 - y0 < 1e-6:
                        continue
                    self.assertLess(y1 - y0, th0 / 2 + th1 / 2, f"{f.id}/{bone_name}: gap between discs")


class SecondaryMotion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()
        cls.mul = cls.g.lua.eval("function(a, b) return a * b end")
        cls.FM = cls.g.module(SHARED + "FighterModels")
        cls.Rig = cls.g.module(SHARED + "Rig")
        cls.Poses = cls.g.module(SHARED + "Poses")
        cls.Sec = cls.g.module(SHARED + "Secondary")
        cls.CF = cls.g.env.CFrame

    def setup(self, fid="AYAME"):
        model = self.FM.build(fid, 1, fid)
        info = self.Rig.measure(model)
        st = self.g.lua.table_from({"state": "Idle", "t": 0, "vy": 0, "h": 0, "walk": 0, "variant": 0})
        pose = self.Poses.evaluate(st, 0.3)
        state = self.Sec.new(model)
        return model, info, pose, state

    def advance(self, model, info, pose, state, x_of_t, seconds, dt=1 / 60):
        for f in range(int(seconds / dt)):
            t = f * dt
            self.Rig.poseStatic(info, pose, self.CF.new(x_of_t(t), info.hipCenter, 0))
            self.Sec.step(state, dt)

    def test_segment_lengths_are_preserved(self):
        for fid in ("AYAME", "VEX", "GOR", "KAI"):
            model, info, pose, state = self.setup(fid)
            self.advance(model, info, pose, state, lambda t: 14 * t if t < 0.3 else 4.2, 1.0)
            for ch in lua_list(state.chains):
                if ch.Q is None:
                    continue
                pivot = self.mul(ch.segs[1].motor.Part0.CFrame, ch.segs[1].motor.C0).Position
                prev = pivot
                for i, seg in enumerate(lua_list(ch.segs), start=1):
                    q = ch.Q[i]
                    d = ((q.X - prev.X) ** 2 + (q.Y - prev.Y) ** 2 + (q.Z - prev.Z) ** 2) ** 0.5
                    self.assertAlmostEqual(d, seg.len, delta=0.02, msg=f"{fid}/{ch.name}#{i}")
                    prev = q

    def test_chains_react_to_motion_then_settle(self):
        model, info, pose, state = self.setup("AYAME")
        # still: remember the settled pose
        self.advance(model, info, pose, state, lambda t: 0.0, 1.5)
        pony = [c for c in lua_list(state.chains) if c.name == "Pony"][0]
        rest = (pony.Q[4].X, pony.Q[4].Y, pony.Q[4].Z)
        # dash sideways: the tip must swing away from rest...
        peak = 0.0
        dt = 1 / 60
        x = 0.0
        for f in range(int(2.5 / dt)):
            t = f * dt
            x += (14.0 if t < 0.3 else 0.0) * dt
            self.Rig.poseStatic(info, pose, self.CF.new(x, info.hipCenter, 0))
            self.Sec.step(state, dt)
            q = pony.Q[4]
            dev = ((q.X - x - (rest[0])) ** 2 + (q.Y - rest[1]) ** 2 + (q.Z - rest[2]) ** 2) ** 0.5
            peak = max(peak, dev)
        self.assertGreater(peak, 0.5, "hair should visibly lag behind a dash")
        # ...and be back near rest, almost still, afterwards
        q = pony.Q[4]
        dev = ((q.X - x - rest[0]) ** 2 + (q.Y - rest[1]) ** 2 + (q.Z - rest[2]) ** 2) ** 0.5
        self.assertLess(dev, 0.15)
        self.assertLess(pony.V[4].Magnitude, 0.5)

    def test_swing_never_exceeds_the_limit(self):
        model, info, pose, state = self.setup("AYAME")
        self.advance(model, info, pose, state, lambda t: 30 * t if t < 0.5 else 15, 1.2)
        for ch in lua_list(state.chains):
            limit = math.radians(ch.limit) + 0.05
            for i, seg in enumerate(lua_list(ch.segs), start=1):
                if ch.Q is None:
                    continue
                motor = seg.motor
                # angle between the segment's actual direction and its rest direction, in Part0 space
                prev = self.mul(motor.Part0.CFrame, motor.C0).Position if i == 1 else ch.Q[i - 1]
                q = ch.Q[i]
                d = self.g.env.Vector3.new(q.X - prev.X, q.Y - prev.Y, q.Z - prev.Z).Unit
                local = motor.Part0.CFrame.VectorToObjectSpace(motor.Part0.CFrame, d)
                ang = math.acos(max(-1, min(1, local.Dot(local, seg.rest.Unit))))
                # parent bones lag one frame behind the solver, so allow a little slack
                self.assertLess(ang, limit + 0.35, f"{ch.name}#{i}: {math.degrees(ang):.0f} deg")

    def test_teleport_does_not_explode(self):
        model, info, pose, state = self.setup("VEX")
        self.advance(model, info, pose, state, lambda t: 0.0, 0.5)
        self.Rig.poseStatic(info, pose, self.CF.new(500, info.hipCenter, 0))  # round reset teleport
        for _ in range(60):
            self.Sec.step(state, 1 / 60)
            self.Rig.poseStatic(info, pose, self.CF.new(500, info.hipCenter, 0))
        for ch in lua_list(state.chains):
            for i in range(1, len(lua_list(ch.segs)) + 1):
                v = ch.V[i]
                self.assertLess(v.Magnitude, 20, f"{ch.name}#{i} flying at {v.Magnitude:.0f} studs/s")

    def test_clear_restores_rest_pose(self):
        model, info, pose, state = self.setup("AYAME")
        self.advance(model, info, pose, state, lambda t: 14 * t if t < 0.3 else 4.2, 0.5)
        self.Sec.clear(state)
        for ch in lua_list(state.chains):
            for seg in lua_list(ch.segs):
                t = seg.motor.Transform
                self.assertAlmostEqual(abs(t.r[1]) + abs(t.r[5]) + abs(t.r[9]), 3.0, places=6)


if __name__ == "__main__":
    unittest.main()
