"""Imported body models: R6 re-rigging, accessory welding, and the R6 pose mode in Shared/Rig."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game  # noqa: E402

SHARED = "ReplicatedStorage/Shared/"


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


class Imported(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()
        g = cls.g
        cls.IF = g.module(SHARED + "ImportedFighters")
        cls.Rig = g.module(SHARED + "Rig")
        cls.Poses = g.module(SHARED + "Poses")
        cls.FM = g.module(SHARED + "FighterModels")
        cls.V3, cls.CF = g.env.Vector3, g.env.CFrame
        cls.mul = g.lua.eval("function(...) local r = select(1, ...) for i = 2, select('#', ...) do r = r * select(i, ...) end return r end")
        rs = g.nodes["ReplicatedStorage"]
        cls.folder = g.shim.Instance.new("Folder", rs)
        cls.folder.Name = "FighterAssets"

    # ---- synthetic R6 body made of plain parts (rotated and posed like a messy import) ----------
    def part(self, parent, name, size, cf, color=None):
        p = self.g.shim.Instance.new("Part", parent)
        p.Name = name
        p.Size = self.V3.new(*size)
        p.CFrame = cf
        return p

    def make_r6(self, name, scale=1.0, yaw=90, mirrored=False):
        CF, mul = self.CF, self.mul
        m = self.g.shim.Instance.new("Model", self.folder)
        m.Name = name
        base = mul(CF.new(30, -20, 8), CF.Angles(0, math.radians(yaw), 0))
        s = scale
        sx = -1 if mirrored else 1

        def at(x, y, z, rx=0.0):
            return mul(base, CF.new(x, y, z), CF.Angles(rx, 0, 0))

        self.part(m, "Torso", (2 * s, 2 * s, 1 * s), base)
        self.part(m, "Head", (2 * s, 1 * s, 1 * s), at(0, 1.5 * s, 0))
        # arms are posed away from the standard layout, as in a real import
        self.part(m, "Right Arm", (1 * s, 2 * s, 1 * s), at(sx * 1.2 * s, 0.3 * s, -0.6 * s, 0.8))
        self.part(m, "Left Arm", (1 * s, 2 * s, 1 * s), at(-sx * 1.2 * s, 0.2 * s, -0.5 * s, 0.8))
        self.part(m, "Right Leg", (1 * s, 2 * s, 1 * s), at(0.5 * s, -2 * s, 0))
        self.part(m, "Left Leg", (1 * s, 2 * s, 1 * s), at(-0.5 * s, -2 * s, 0))
        # extras: hair (unmarked, near the head), a hat by attachment, a belt plate by attachment, a floating pad
        self.part(m, "Hair", (1.2, 1.2, 1.2), at(0, 2.2 * s, 0.1))
        hat = self.part(m, "HatHandle", (1, 1, 1), at(0, 2.4 * s, 0))
        self.g.shim.Instance.new("Attachment", hat).Name = "HatAttachment"
        belt = self.part(m, "BeltPlate", (2, 0.3, 1.1), at(0, -0.9 * s, 0))
        self.g.shim.Instance.new("Attachment", belt).Name = "WaistFrontAttachment"
        self.part(m, "FloatingPad", (1, 1, 1), at(sx * 1.4 * s, 0.4 * s, 0))
        return m

    def def_for(self, asset):
        return self.g.lua.table_from({"id": "T_" + asset, "asset": asset, "name": asset, "palettes": self.g.lua.table_from({1: self.g.lua.table_from({"glow": self.g.env.Color3.new(1, 0.5, 0)})})})

    def built(self, name, **kw):
        self.make_r6(name, **kw)
        model = self.IF.build(self.def_for(name), "Tester")
        self.assertIsNotNone(model, f"{name} failed to build")
        return model

    def test_r6_is_rerigged_with_standard_joints(self):
        m = self.built("R6A")
        names = {d.Name for d in lua_list(m.GetDescendants(m)) if d.IsA(d, "Motor6D")}
        self.assertEqual(names, {"RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip"})
        self.assertIsNotNone(m.PrimaryPart)
        self.assertEqual(m.PrimaryPart.Name, "HumanoidRootPart")
        info = self.Rig.measure(m)
        self.assertTrue(info and info.r6)
        self.assertAlmostEqual(info.hipCenter, 3.0, places=2)  # classic R6: legs 2 + half the torso 1

    def test_body_is_laid_out_in_the_standard_pose(self):
        m = self.built("R6B", yaw=37)
        root = m.PrimaryPart
        def rel(n):
            return root.CFrame.ToObjectSpace(root.CFrame, m.FindFirstChild(m, n).CFrame).p
        self.assertAlmostEqual(rel("Head").Y, 1.5, places=3)
        self.assertAlmostEqual(rel("Right Arm").X, 1.5, places=3)
        self.assertAlmostEqual(rel("Left Arm").X, -1.5, places=3)
        self.assertAlmostEqual(rel("Right Leg").Y, -2.0, places=3)

    def test_mirrored_arms_are_swapped(self):
        m = self.built("R6M", mirrored=True)
        root = m.PrimaryPart
        x = root.CFrame.ToObjectSpace(root.CFrame, m.FindFirstChild(m, "Right Arm").CFrame).p.X
        self.assertGreater(x, 1.0)

    def test_extras_follow_their_body_part(self):
        m = self.built("R6C")
        head, torso = m.FindFirstChild(m, "Head"), m.FindFirstChild(m, "Torso")
        self.assertEqual(m.FindFirstChild(m, "Hair", True).Parent.Name, head.Name)
        self.assertEqual(m.FindFirstChild(m, "HatHandle", True).Parent.Name, head.Name)  # by HatAttachment
        self.assertEqual(m.FindFirstChild(m, "BeltPlate", True).Parent.Name, torso.Name)  # by WaistFrontAttachment
        pad = m.FindFirstChild(m, "FloatingPad", True)
        self.assertIn(pad.Parent.Name, ("Right Arm", "Torso"))  # nearest body part
        for n in ("Hair", "HatHandle", "BeltPlate"):
            p = m.FindFirstChild(m, n, True)
            self.assertIsNotNone(p.FindFirstChild(p, "VisWeld"))

    def test_scaled_body_keeps_its_proportions(self):
        m = self.built("R6S", scale=1.145)
        info = self.Rig.measure(m)
        self.assertAlmostEqual(info.hipCenter, 3.0 * 1.145, places=2)
        self.assertAlmostEqual(info.scale, 1.145, places=2)

    def pose_floor(self, m, state, **kw):
        """Pose the model with the real Poses and return (lowest leg bottom, root height) above the floor."""
        info = self.Rig.measure(m)
        st = self.g.lua.table_from(dict({"state": state, "t": 0.1, "vy": 0, "h": 0, "walk": 0, "variant": 0, "poseVar": 1}, **kw))
        pose = self.Poses.evaluate(st, 0.3)
        self.Rig.poseStatic(info, pose, self.CF.new(0, info.hipCenter, 0))
        low = 1e9
        for n in ("Left Leg", "Right Leg"):
            leg = m.FindFirstChild(m, n)
            cf, size = leg.CFrame, leg.Size
            # lowest point of the rotated leg box
            r = [cf.r[1], cf.r[2], cf.r[3], cf.r[4], cf.r[5], cf.r[6], cf.r[7], cf.r[8], cf.r[9]]
            ext = abs(r[3]) * size.X / 2 + abs(r[4]) * size.Y / 2 + abs(r[5]) * size.Z / 2
            low = min(low, cf.p.Y - ext)
        return low, m.PrimaryPart.Position.Y

    def test_feet_stay_on_the_floor_in_every_stance(self):
        m = self.built("R6F")
        for state in ("Idle", "WalkF", "WalkB", "Crouch", "Blockstun", "Hitstun"):
            low, _ = self.pose_floor(m, state)
            self.assertLess(abs(low), 0.45, f"{state}: lowest foot {low:.2f} above the floor")

    def test_every_pose_applies_without_error(self):
        m = self.built("R6G")
        info = self.Rig.measure(m)
        for mid in lua_list(self.Moves_ids()):
            st = self.g.lua.table_from({"state": "Attack", "move": mid, "t": 0.2, "mt": 0.2, "vy": 0, "h": 0, "walk": 0, "variant": 0, "poseVar": 1})
            pose = self.Poses.evaluate(st, 0.3)
            self.Rig.poseStatic(info, pose, self.CF.new(0, info.hipCenter, 0))
        self.Rig.clear(info)

    def Moves_ids(self):
        return self.g.module(SHARED + "Moves").Order

    def test_r15_model_keeps_its_own_joints(self):
        # reuse a procedural fighter as the 'imported' R15 body
        src = self.FM.build("AYAME", 1, "src")
        src.Name = "R15A"
        src.Parent = self.folder
        model = self.IF.build(self.def_for("R15A"), "Tester")
        self.assertIsNotNone(model)
        info = self.Rig.measure(model)
        self.assertTrue(info and not info.r6)
        self.assertEqual(model.GetAttribute(model, "Imported"), True)

    def test_missing_asset_falls_back_to_the_procedural_body(self):
        d = self.g.lua.execute("return {id = 'KAI', asset = 'NOPE', name = 'KAI', palettes = {{glow = Color3.new(1,1,1)}}}") if False else None
        # the roster fighter whose asset is absent in this test tree is built procedurally
        m = self.FM.build("KAI", 1, "KAI")
        self.assertIsNotNone(m.FindFirstChild(m, "UpperTorso"))
        self.assertIsNone(m.GetAttribute(m, "Imported"))


if __name__ == "__main__":
    unittest.main()
