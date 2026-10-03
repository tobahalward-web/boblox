"""HubGrit: the finishing pass dims lights by Config.Hub.lightScale, switches on shadows for big structures,
adds contact shading / stains / haze under Hub.Grit, and leaves everything the modules built untouched."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game  # noqa: E402

MODS = "ServerScriptService/IronClashServer/Modules/"

MEASURE = """function(root)
  local o = { parts = 0, own = 0, cast = 0, lights = 0, light_sum = 0, bad = 0, opaque = 0, colliding = 0, haze = 0, shade = 0, stains = 0 }
  local grit = root:FindFirstChild("Grit")
  for _, d in ipairs(root:GetDescendants()) do
    local inGrit = false
    local p = d.Parent
    while p and p ~= root do
      if p == grit then inGrit = true end
      p = p.Parent
    end
    if d:IsA("BasePart") then
      o.parts = o.parts + 1
      if inGrit then
        o.own = o.own + 1
        local s = d.Size
        if math.min(s.X, s.Y, s.Z) < 0.05 then o.bad = o.bad + 1 end
        if d.Transparency <= 0.1 and d.Reflectance == 0 then o.opaque = o.opaque + 1 end
        if d.CanCollide or not d.Anchored or d.CastShadow then o.colliding = o.colliding + 1 end
      elseif d.CastShadow then
        o.cast = o.cast + 1
      end
    elseif d:IsA("Light") then
      o.lights = o.lights + 1
      o.light_sum = o.light_sum + d.Brightness
    elseif d.ClassName == "ParticleEmitter" and inGrit then
      o.haze = o.haze + 1
    end
  end
  if grit then
    local sh, st = grit:FindFirstChild("Shade"), grit:FindFirstChild("Stains")
    o.shade = sh and #sh:GetChildren() or 0
    o.stains = st and #st:GetChildren() or 0
  end
  return o
end"""


def build(**cfg):
    g = Game()
    c = g.module("ReplicatedStorage/Shared/Config")
    for k, v in cfg.items():
        c.Hub[k] = v
    hub = g.module(MODS + "Hub").build()
    o = g.lua.eval(MEASURE)(hub)
    return g, {k: o[k] for k in ("parts", "own", "cast", "lights", "light_sum", "bad", "opaque", "colliding", "haze", "shade", "stains")}


class HubGrit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw_g, cls.raw = build(lightScale=1, shadows=False, grime=False)
        cls.default_g, cls.default = build()

    def test_no_warnings(self):
        w = self.default_g.env.__warnings
        self.assertEqual([w[k] for k in sorted(w.keys())] if w else [], [])

    def test_lights_are_dimmed_by_the_dial(self):
        scale = self.default_g.module("ReplicatedStorage/Shared/Config").Hub.lightScale
        self.assertLess(scale, 1)
        self.assertEqual(self.default["lights"], self.raw["lights"])
        self.assertAlmostEqual(self.default["light_sum"] / self.raw["light_sum"], scale, places=3)

    def test_the_dial_at_one_leaves_lights_alone(self):
        _, o = build(lightScale=1)
        self.assertAlmostEqual(o["light_sum"], self.raw["light_sum"], places=3)

    def test_big_structures_cast_shadows(self):
        self.assertGreater(self.default["cast"], self.raw["cast"] * 1.5)
        _, off = build(shadows=False)
        self.assertEqual(off["cast"], self.raw["cast"])

    def test_grit_is_added_and_well_formed(self):
        d = self.default
        self.assertGreater(d["shade"], 150)
        self.assertGreater(d["stains"], 800)
        self.assertGreater(d["haze"], 30)
        self.assertEqual(d["bad"], 0, "a grit part is thinner than Roblox's 0.05 minimum")
        self.assertEqual(d["opaque"], 0, "grit must be translucent or glossy, never a solid slab")
        self.assertEqual(d["colliding"], 0, "grit parts must be anchored, non-colliding and cast no shadow")
        self.assertLess(d["own"], 6500)

    def test_nothing_the_modules_built_is_changed(self):
        # without grime the only differences are the lights and shadow flags, so the part count matches
        self.assertEqual(self.default["parts"] - self.default["own"], self.raw["parts"])

    def test_grime_can_be_switched_off(self):
        _, o = build(grime=False)
        self.assertEqual(o["own"], 0)
        self.assertEqual(o["haze"], 0)


if __name__ == "__main__":
    unittest.main()
