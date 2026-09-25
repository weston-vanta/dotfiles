"""Unit tests for wt's pure logic. Run: python3 -m unittest bin/test_wt.py (from ~/dotfiles)."""

import importlib.machinery
import importlib.util
import sys
import unittest
from pathlib import Path

spec = importlib.util.spec_from_loader(
    "wt", importlib.machinery.SourceFileLoader("wt", str(Path(__file__).with_name("wt")))
)
wt = importlib.util.module_from_spec(spec)
# Dataclasses resolve postponed annotations via sys.modules, so register before exec.
sys.modules["wt"] = wt
spec.loader.exec_module(wt)


class NameValidation(unittest.TestCase):
    def test_accepts_slugs(self):
        for name in ("a", "fix-login", "rmon.118_x", "0abc"):
            self.assertEqual(wt.validate_name(name), name)

    def test_rejects_unsafe_names(self):
        for name in ("", "Bad", "has space", "../etc", "-leading", "a/b", "x" * 65):
            with self.assertRaises(wt.WtError, msg=name):
                wt.validate_name(name)


class Layout(unittest.TestCase):
    def test_paths_and_branch(self):
        self.assertEqual(wt.mount_point("foo"), wt.MOUNTS / "foo")
        self.assertEqual(wt.upper_dir("foo"), wt.STATE / "foo" / "upper")
        self.assertEqual(wt.work_dir("foo"), wt.STATE / "foo" / "work")
        self.assertEqual(wt.default_branch("foo"), f"{wt.BRANCH_PREFIX}/foo")


class MountParsing(unittest.TestCase):
    def test_only_overlay_mounts_under_any_path(self):
        text = "\n".join(
            [
                "/dev/nvme1n1 /workspaces ext4 rw,relatime 0 0",
                "overlay /workspaces/wt/a overlay rw,lowerdir=/x,upperdir=/y 0 0",
                "overlay / overlay rw 0 0",
                "tmpfs /tmp tmpfs rw 0 0",
                "overlay /workspaces/wt/b overlay rw 0 0",
            ]
        )
        self.assertEqual(
            wt.parse_overlay_mounts(text),
            {Path("/workspaces/wt/a"), Path("/workspaces/wt/b"), Path("/")},
        )

    def test_empty(self):
        self.assertEqual(wt.parse_overlay_mounts(""), set())


class FuserParsing(unittest.TestCase):
    def test_pids_with_access_suffixes(self):
        self.assertEqual(wt.parse_fuser_pids(" 123c 456 789f\n"), [123, 456, 789])

    def test_ignores_self_and_empty(self):
        self.assertEqual(wt.parse_fuser_pids("123 999", ignore={999}), [123])
        self.assertEqual(wt.parse_fuser_pids(""), [])
        self.assertEqual(wt.parse_fuser_pids("\n"), [])


class StateDiscovery(unittest.TestCase):
    def test_names_require_upper_dir(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "b" / "upper").mkdir(parents=True)
            (root / "a" / "upper").mkdir(parents=True)
            (root / "stale-no-upper").mkdir()
            (root / "file").write_text("")
            self.assertEqual(wt.worktree_names_from_state(root), ["a", "b"])
        self.assertEqual(wt.worktree_names_from_state(Path("/nonexistent/x")), [])


class Formatting(unittest.TestCase):
    def test_human_age(self):
        self.assertEqual(wt.human_age(90), "1m")
        self.assertEqual(wt.human_age(5400), "1.5h")
        self.assertEqual(wt.human_age(3 * 86400), "3.0d")

    def test_human_bytes(self):
        self.assertEqual(wt.human_bytes(0), "0B")
        self.assertEqual(wt.human_bytes(2048), "2K")
        self.assertEqual(wt.human_bytes(5 * 1024**3), "5.0G")

    def test_render_list_flags(self):
        out = wt.render(
            "list",
            {
                "worktrees": [
                    {
                        "name": "a",
                        "path": "/workspaces/wt/a",
                        "mounted": True,
                        "branch": "weston/a",
                        "dirty_files": 2,
                        "busy": True,
                        "upper_bytes": 1024,
                    },
                    {"name": "b", "path": "/workspaces/wt/b", "mounted": False, "upper_bytes": 0},
                ]
            },
        )
        self.assertIn("dirty(2)", out)
        self.assertIn("busy", out)
        self.assertIn("UNMOUNTED", out)


if __name__ == "__main__":
    unittest.main()
