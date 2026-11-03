import json
import os
import subprocess
import tempfile
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "keycount_setup.py"


class SetupTests(unittest.TestCase):
    def run_setup(self, home, *args):
        environment = os.environ | {"HOME": str(home)}
        return subprocess.run(["python3", str(SCRIPT), *args], env=environment, text=True, capture_output=True)

    def test_binding_is_added_once(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            bindings = home / ".config" / "hypr" / "bindings.lua"
            bindings.parent.mkdir(parents=True)
            bindings.write_text('o.bind("SUPER + SHIFT + S", "Screenshot", "shot")\n', encoding="utf-8")
            self.assertEqual(self.run_setup(home, "--ensure-binding").returncode, 0)
            self.assertEqual(self.run_setup(home, "--ensure-binding").returncode, 0)
            content = bindings.read_text(encoding="utf-8")
            self.assertEqual(content.count("-- Keycount plugin binding"), 1)
            self.assertIn('panel = "io.github.noobyco.keycount"', content)

    def test_placement_is_written(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            self.assertEqual(self.run_setup(home, "--placement", "bottom-left-edge").returncode, 0)
            config = home / ".config" / "omarchy" / "keycount.json"
            self.assertEqual(json.loads(config.read_text(encoding="utf-8"))["position"], "bottom-left-edge")

    def test_placement_preserves_unified_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            config = home / ".config" / "omarchy" / "keycount.json"
            config.parent.mkdir(parents=True)
            config.write_text(json.dumps({"bestSpeed": 72, "bestDate": "2026-11-03", "streak": 2}), encoding="utf-8")
            self.assertEqual(self.run_setup(home, "--placement", "top-right-edge").returncode, 0)
            self.assertEqual(json.loads(config.read_text(encoding="utf-8")), {
                "bestSpeed": 72,
                "bestDate": "2026-11-03",
                "streak": 2,
                "position": "top-right-edge",
            })

    def test_binding_can_be_removed_without_touching_other_lines(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            self.run_setup(home, "--ensure-binding")
            bindings = home / ".config" / "hypr" / "bindings.lua"
            bindings.write_text(bindings.read_text(encoding="utf-8") + 'o.bind("SUPER + X", "Other", "other")\n', encoding="utf-8")
            self.assertEqual(self.run_setup(home, "--remove-binding").returncode, 0)
            content = bindings.read_text(encoding="utf-8")
            self.assertNotIn("Keycount plugin binding", content)
            self.assertIn('o.bind("SUPER + X", "Other", "other")', content)


if __name__ == "__main__":
    unittest.main()
