"""Run the actual recipe body with isolated Python packages and real symlinks."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


RECIPE = Path(__file__).resolve().parents[1] / 'mix.just'
SOURCE = textwrap.dedent(RECIPE.read_text().split('where:\n', 1)[1])


class MixWhereTests(unittest.TestCase):
    def run_where(self, files):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, content in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            if files:
                (root / 'memryx/mxa.py').symlink_to('actual_mxa.py')
            result = subprocess.run(
                [sys.executable, '-S', '-c', SOURCE], cwd=root,
                env={**os.environ, 'PYTHONPATH': directory},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('Traceback', result.stderr)
            return result.stdout, root

    def test_missing_memryx_still_reports_every_module_and_native_library(self):
        output, _ = self.run_where({})
        self.assertEqual(output.count('Missing module: memryx'), 3)
        for heading in ('python\n', 'memryx\n', 'mxapi\n', 'mxa\n',
                        'runtime  (libmx_accl.so)', 'driver  (libmemx.so)'):
            self.assertIn(heading, output)

    def test_missing_mxapi_dependency_still_reports_mxa_symlink_and_libraries(self):
        output, root = self.run_where({
            'memryx/__init__.py': '',
            'memryx/mxapi.py': 'import missing_mxapi_dependency\n',
            'memryx/actual_mxa.py': '',
        })
        self.assertIn('Missing module: missing_mxapi_dependency', output)
        self.assertIn('mxa  (memryx.mxa)', output)
        self.assertIn(f'Imported from:  {root}/memryx/mxa.py', output)
        self.assertIn(f'Links to:       {root}/memryx/actual_mxa.py', output)
        self.assertIn('driver  (libmemx.so)', output)

    def test_broken_mxa_import_does_not_hide_runtime_reexport_or_libraries(self):
        output, root = self.run_where({
            'memryx/__init__.py': 'from .runtime import mxapi\n',
            'memryx/runtime/__init__.py': '',
            'memryx/runtime/mxapi.py': '',
            'memryx/actual_mxa.py': "raise OSError('cannot load driver')\n",
        })
        self.assertIn('mxapi  (memryx.runtime.mxapi)', output)
        self.assertIn(f'{root}/memryx/runtime/mxapi.py', output)
        self.assertIn('OSError: cannot load driver', output)
        self.assertIn('runtime  (libmx_accl.so)', output)
        self.assertIn('driver  (libmemx.so)', output)


if __name__ == '__main__':
    unittest.main()
