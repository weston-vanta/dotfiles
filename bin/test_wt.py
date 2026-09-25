"""Unit tests for wt's pure logic. Run: python3 -m unittest bin/test_wt.py (from ~/dotfiles)."""

import importlib.machinery
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_loader(
    "wt", importlib.machinery.SourceFileLoader("wt", str(Path(__file__).with_name("wt")))
)
wt = importlib.util.module_from_spec(spec)
# Dataclasses resolve postponed annotations via sys.modules, so register before exec.
sys.modules["wt"] = wt
spec.loader.exec_module(wt)


class Layout(unittest.TestCase):
    def test_sibling_layout_and_nested_names(self):
        repo = wt.Repo(root=Path("/workspaces/obsidian"), base_ref="origin/main")
        self.assertEqual(repo.wt_dir, Path("/workspaces/obsidian.wt"))
        self.assertEqual(repo.base, Path("/workspaces/obsidian.wt/.base"))
        self.assertEqual(repo.state, Path("/workspaces/obsidian.wt/.state"))
        self.assertEqual(repo.mount_point("weston/fix"), Path("/workspaces/obsidian.wt/weston/fix"))
        self.assertEqual(repo.upper_dir("weston/fix"), Path("/workspaces/obsidian.wt/.state/weston/fix/upper"))
        self.assertEqual(repo.work_dir("a"), Path("/workspaces/obsidian.wt/.state/a/work"))

    def test_state_dir_override(self):
        repo = wt.Repo(root=Path("/home/u/dotfiles"), base_ref="origin/main", state_dir=Path("/workspaces/.wt-state/dotfiles"))
        self.assertEqual(repo.upper_dir("t/x"), Path("/workspaces/.wt-state/dotfiles/t/x/upper"))
        self.assertEqual(repo.mount_point("t/x"), Path("/home/u/dotfiles.wt/t/x"))

    def test_upperdir_filesystem_support(self):
        self.assertTrue(wt.fs_type_supports_upperdir("ext2/ext3"))
        self.assertTrue(wt.fs_type_supports_upperdir("xfs"))
        self.assertFalse(wt.fs_type_supports_upperdir("overlayfs"))
        self.assertFalse(wt.fs_type_supports_upperdir("nfs"))

    def test_default_branch_strips_remote(self):
        self.assertEqual(wt.Repo(root=Path("/r"), base_ref="origin/main").default_branch, "main")
        self.assertEqual(wt.Repo(root=Path("/r"), base_ref="origin/release/1").default_branch, "release/1")


class MountParsing(unittest.TestCase):
    def test_only_overlay_mounts(self):
        text = "\n".join(
            [
                "/dev/nvme1n1 /workspaces ext4 rw,relatime 0 0",
                "overlay /workspaces/obsidian.wt/a overlay rw,lowerdir=/x,upperdir=/y 0 0",
                "overlay / overlay rw 0 0",
                "tmpfs /tmp tmpfs rw 0 0",
                "overlay /workspaces/obsidian.wt/b/c overlay rw 0 0",
            ]
        )
        self.assertEqual(
            wt.parse_overlay_mounts(text),
            {Path("/workspaces/obsidian.wt/a"), Path("/workspaces/obsidian.wt/b/c"), Path("/")},
        )

    def test_empty(self):
        self.assertEqual(wt.parse_overlay_mounts(""), set())


class FuserParsing(unittest.TestCase):
    def test_pids_with_access_suffixes(self):
        self.assertEqual(wt.parse_fuser_pids(" 123c 456 789f\n"), [123, 456, 789])

    def test_ignores_self_and_empty(self):
        self.assertEqual(wt.parse_fuser_pids("123 999", ignore={999}), [123])
        self.assertEqual(wt.parse_fuser_pids(""), [])


class MergeClassification(unittest.TestCase):
    def test_up_to_date_wins(self):
        self.assertEqual(wt.classify_merge(True, True), "up-to-date")
        self.assertEqual(wt.classify_merge(False, True), "up-to-date")

    def test_fast_forward_when_branch_behind(self):
        self.assertEqual(wt.classify_merge(True, False), "fast-forward")

    def test_diverged_needs_merge(self):
        self.assertEqual(wt.classify_merge(False, False), "merge")


class StateDiscovery(unittest.TestCase):
    def test_nested_names_require_upper_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "b" / "upper").mkdir(parents=True)
            (root / "weston" / "fix" / "upper").mkdir(parents=True)
            (root / "weston" / "fix" / "work").mkdir()
            (root / "a" / "upper").mkdir(parents=True)
            (root / "stale-no-upper").mkdir()
            (root / "file").write_text("")
            self.assertEqual(wt.worktree_names_from_state(root), ["a", "b", "weston/fix"])
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
                "repo": "/r",
                "worktrees": [
                    {"name": "a", "path": "/r.wt/a", "mounted": True, "branch": "a", "dirty_files": 2, "busy": True, "upper_bytes": 1024},
                    {"name": "b", "path": "/r.wt/b", "mounted": False, "upper_bytes": 0},
                ],
            },
        )
        self.assertIn("dirty(2)", out)
        self.assertIn("busy", out)
        self.assertIn("UNMOUNTED", out)

    def test_guide_without_repo_uses_placeholders(self):
        text = wt.guide_text(None)
        self.assertIn("<repo>.wt", text)
        self.assertIn("plain checkout", text)

    def test_guide_with_repo_lists_warm_commands(self):
        repo = wt.Repo(root=Path("/w/x"), base_ref="origin/main", warm=["just pp", "turbo run typecheck"])
        text = wt.guide_text(repo)
        self.assertIn("/w/x.wt/<branch>", text)
        self.assertIn("    just pp", text)


if __name__ == "__main__":
    unittest.main()
