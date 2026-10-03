"""The built place file must be loadable by Studio: no shared string declared twice, no repeated item referents,
no repeated top-level asset folders, and every shared-string reference resolves."""
import collections
import re
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class BuiltPlace(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        out = Path(cls.tmp.name) / "place.rbxlx"
        subprocess.run([sys.executable, str(ROOT / "tools" / "build.py"), str(ROOT / "IronClash"), str(out)], check=True, capture_output=True)
        cls.text = out.read_text(encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_xml_is_well_formed(self):
        ET.fromstring(self.text.encode("utf-8"))

    def test_shared_strings_are_declared_once(self):
        ids = re.findall(r'<SharedString md5="([^"]+)"', self.text)
        self.assertEqual([k for k, v in collections.Counter(ids).items() if v > 1], [])
        refs = set(re.findall(r'<SharedString name="[^"]*">([^<]+)</SharedString>', self.text))
        self.assertEqual([r for r in refs if r not in ids], [], "a shared string is used but never declared")

    def test_item_referents_are_unique(self):
        refs = re.findall(r'<Item class="[^"]+" referent="([^"]+)"', self.text)
        self.assertEqual([k for k, v in collections.Counter(refs).items() if v > 1], [])

    def test_imported_fighter_models_are_in_once(self):
        self.assertEqual(self.text.count('<string name="Name">FighterAssets</string>'), 1)


if __name__ == "__main__":
    unittest.main()
