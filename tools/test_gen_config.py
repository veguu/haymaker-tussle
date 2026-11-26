"""Regression tests; run python -B tools/test_gen_config.py (standard library only)."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
import gen_config as generator


class GeneratorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'design').mkdir()
        (self.root / 'design/game.json').write_text(
            json.dumps({'config': {'Enabled': True, 'Speed': 1.25, 'Names': ['a', 'b']}}),
            encoding='utf-8',
        )
        self.out = self.root / 'src/shared/Config/GameConfig.luau'

    def run_main(self, *args):
        with patch.object(sys, 'argv', ['gen_config.py', '--dir', str(self.root), *args]):
            with contextlib.redirect_stdout(io.StringIO()):
                return generator.main()

    def test_check_generation_drift_and_missing_output(self):
        with patch.object(generator, 'stylua', side_effect=lambda text, root: text):
            self.assertEqual(self.run_main('--check'), 1)
            self.assertFalse(self.out.parent.exists())
            self.assertEqual(self.run_main(), 0)
            original = self.out.read_bytes()
            self.assertNotIn(b'\r', original)
            self.assertEqual(self.run_main('--check'), 0)
            self.out.write_bytes(original + b'-- drift\n')
            drifted = self.out.read_bytes()
            self.assertEqual(self.run_main('--check'), 1)
            self.assertEqual(self.out.read_bytes(), drifted)

    def test_missing_formatter_preserves_existing_output(self):
        self.out.parent.mkdir(parents=True)
        self.out.write_bytes(b'keep existing output')
        with patch.object(generator.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'missing'):
                self.run_main()
        self.assertEqual(self.out.read_bytes(), b'keep existing output')

    def test_failed_formatter_creates_no_output(self):
        with patch.object(generator.shutil, 'which', return_value='stylua'):
            with patch.object(generator.subprocess, 'run', side_effect=
                              subprocess.CalledProcessError(1, ['stylua'], stderr=b'invalid input')):
                with self.assertRaisesRegex(RuntimeError, 'invalid input'):
                    self.run_main()
        self.assertFalse(self.out.exists())

    def test_formatter_timeout_creates_no_output(self):
        with patch.object(generator.shutil, 'which', return_value='stylua'):
            with patch.object(generator.subprocess, 'run', side_effect=
                              subprocess.TimeoutExpired(['stylua'], 60)):
                with self.assertRaisesRegex(RuntimeError, 'could not complete'):
                    self.run_main()
        self.assertFalse(self.out.exists())

    def test_serialization_preserves_types_and_precision(self):
        self.assertEqual(generator.emit(True), 'true')
        self.assertEqual(generator.emit(None), 'nil')
        self.assertEqual(generator.emit('a"b\\c'), '"a\\"b\\\\c"')
        self.assertIn('["end"] = 1', generator.emit({'end': 1}))
        for number in [0.125, 1e-9, 1e20, 1e36, -3.5]:
            self.assertEqual(float(generator.num(number)), number)
        with self.assertRaises(ValueError):
            generator.num(float('nan'))

    def test_real_project_check_from_other_directory(self):
        script = Path(generator.__file__).resolve()
        out = script.parent.parent / 'src/shared/Config/GameConfig.luau'
        before = out.read_bytes()
        result = subprocess.run([sys.executable, '-B', str(script), '--check'],
                                cwd=self.root, capture_output=True, text=True, timeout=70)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(out.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
