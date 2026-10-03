"""The hub's dawn/dusk sky: both looks are complete, the sun stays low, Config.Hub.sky picks between them,
the hub theme applies cleanly, and the place file's saved lighting matches the dusk look."""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
THEMES = "StarterPlayer/StarterPlayerScripts/IronClashClient/Themes"
KEYS = ["ClockTime", "Brightness", "GeographicLatitude", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
        "ExposureCompensation", "ColorShift_Top", "ColorShift_Bottom", "Atmosphere", "Bloom", "CC", "SunRays", "DOF", "Sky", "Clouds", "Particles"]


class HubSky(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()
        cls.themes = cls.g.module(THEMES)
        cls.config = cls.g.module("ReplicatedStorage/Shared/Config")

    def preset(self, name):
        return self.themes.Presets[name]

    def test_both_looks_are_complete(self):
        for name in ("HubDusk", "HubDawn"):
            p = self.preset(name)
            for k in KEYS:
                self.assertIsNotNone(p[k], f"{name} is missing {k}")
            for k in ("Density", "Offset", "Color", "Decay", "Glare", "Haze"):
                self.assertIsNotNone(p.Atmosphere[k], f"{name}.Atmosphere.{k}")

    def test_sun_is_low_at_dusk_and_dawn(self):
        dusk, dawn = self.preset("HubDusk"), self.preset("HubDawn")
        # sunset at this latitude is around 18:00, sunrise around 06:00: the whole drift range must stay near them
        for p, lo, hi in ((dusk, 17.0, 18.2), (dawn, 5.9, 7.0)):
            d = p.Drift
            self.assertGreater(d.period, 60)
            self.assertGreaterEqual(d.base - d.amp, lo)
            self.assertLessEqual(d.base + d.amp, hi)
            self.assertAlmostEqual(p.ClockTime, d.base, places=3)

    def test_sky_choice_follows_config(self):
        want = "HubDawn" if self.config.Hub.sky == "dawn" else "HubDusk"
        self.assertTrue(self.g.lua.eval("rawequal")(self.themes.Presets.Hub, self.preset(want)), f"Presets.Hub should be {want}")
        self.assertIn(self.config.Hub.sky, ("dusk", "dawn"))

    def test_the_glow_is_visible(self):
        # Atmosphere only paints a horizon glow when Haze and Glare are both above zero
        for name in ("HubDusk", "HubDawn"):
            a = self.preset(name).Atmosphere
            self.assertGreater(a.Haze, 1)
            self.assertGreater(a.Glare, 0.3)

    def test_hub_theme_applies(self):
        self.themes.apply("Hub", True)
        w = self.g.env.__warnings
        msgs = [w[k] for k in sorted(w.keys())] if w else []
        self.assertEqual([m for m in msgs if "Themes" in m], [])

    def test_place_file_saves_the_dusk_look(self):
        text = (ROOT / "IronClash" / "place.rbxlx.tmpl").read_text(encoding="utf-8")
        dusk = self.preset("HubDusk")
        h, m = int(dusk.ClockTime), round((dusk.ClockTime % 1) * 60)
        self.assertIn(f'<string name="TimeOfDay">{h:02d}:{m:02d}:00</string>', text)
        i = text.index('<Item class="Atmosphere"')
        atmo = text[i:text.index("</Item>", i)]
        self.assertAlmostEqual(float(re.search(r'name="Haze">([^<]+)<', atmo).group(1)), dusk.Atmosphere.Haze, places=3)
        self.assertAlmostEqual(float(re.search(r'name="Glare">([^<]+)<', atmo).group(1)), dusk.Atmosphere.Glare, places=3)


if __name__ == "__main__":
    unittest.main()
