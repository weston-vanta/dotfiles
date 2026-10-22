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


def entry(kind, links, disk_bytes, path, size=None):
    return wt.Entry(kind, links, disk_bytes, disk_bytes if size is None else size, path)


def lower(links, disk_bytes, size=None, kind="f"):
    return wt.LowerFile(kind == "d", kind == "f", links, disk_bytes, disk_bytes if size is None else size)


class DiskAccounting(unittest.TestCase):
    def test_tally_splits_hardlinked_files(self):
        out = "d 5 8\nf 1 16\nf 3 64\nl 1 0\nc 1 0\n"
        self.assertEqual(wt.tally_usage(out), wt.Usage(unique_bytes=24 * 512, shared_bytes=64 * 512))

    def test_parse_entries_keeps_spaces_and_root(self):
        out = "d 4 8 4096 \0f 1 8 3000 dir/a file.txt\0c 1 0 0 gone\0"
        self.assertEqual(
            wt.parse_find_entries(out),
            [
                wt.Entry("d", 4, 4096, 4096, ""),
                wt.Entry("f", 1, 4096, 3000, "dir/a file.txt"),
                wt.Entry("c", 1, 0, 0, "gone"),
            ],
        )

    def test_summarize_upper_overlap(self):
        base = {
            "changed": lower(1, 4000),
            "deleted": lower(1, 500),
            "from-store": lower(2, 9000),
            "pkg": lower(1, 0, kind="d"),
        }
        entries = [
            entry("d", 3, 100, ""),
            entry("d", 2, 100, "pkg"),
            entry("f", 1, 4000, "changed"),
            entry("c", 1, 0, "deleted"),
            entry("f", 1, 9000, "from-store"),
            entry("f", 2, 7000, "pkg/linked"),
            entry("f", 1, 300, "new"),
        ]
        usage = wt.summarize_upper(entries, base.get)
        self.assertEqual(usage.unique_bytes, 100 + 100 + 4000 + 9000 + 300)
        self.assertEqual(usage.shared_bytes, 7000)
        # Only singly-linked base files are freed by replacing them; the store copy stays.
        self.assertEqual(usage.shadowed_bytes, 4000 + 500)
        self.assertIsNone(usage.identical_bytes)

    def test_identical_needs_same_size_and_content(self):
        base = {"same": lower(1, 4096, 10), "resized": lower(1, 4096, 10), "edited": lower(1, 4096, 10)}
        entries = [
            entry("f", 1, 4096, "same", 10),
            entry("f", 1, 4096, "resized", 11),
            entry("f", 1, 4096, "edited", 10),
            entry("f", 1, 4096, "new", 10),
        ]
        compared = []

        def same(rel):
            compared.append(rel)
            return rel == "same"

        usage = wt.summarize_upper(entries, base.get, same)
        self.assertEqual(usage.identical_bytes, 4096)
        self.assertEqual(compared, ["same", "edited"])

    def test_savings_against_plain_checkouts(self):
        uppers = [wt.UpperUsage(10, 0, 4, None), wt.UpperUsage(30, 5, 20, None)]
        self.assertEqual(
            wt.estimate_savings(100, uppers),
            {"wt_bytes": 140, "git_bytes": (100 - 4 + 10) + (100 - 20 + 30), "saved_bytes": 76},
        )

    def test_base_stats_round_trip_and_garbage(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = wt.Repo(root=Path(tmp) / "r", base_ref="origin/main")
            self.assertIsNone(wt.read_base_stats(repo))
            repo.wt_dir.mkdir()
            repo.base_stats_file.write_text("not json")
            self.assertIsNone(wt.read_base_stats(repo))
            repo.base_stats_file.write_text('{"commit": "abc", "unique_bytes": 1, "shared_bytes": 2, "warm_seconds": null}')
            self.assertEqual(wt.read_base_stats(repo), wt.BaseStats("abc", 1, 2, None))


class Parallel(unittest.TestCase):
    def test_results_keyed_by_job(self):
        self.assertEqual(wt.run_parallel("x", {"a": lambda: 1, "b": lambda: 2}), {"a": 1, "b": 2})
        self.assertEqual(wt.run_parallel("x", {}), {})

    def test_progress_line(self):
        self.assertEqual(wt.progress_line("measuring", 3, 9, 12.4), "wt: measuring 3/9 (12s)")


class Formatting(unittest.TestCase):
    def test_human_age(self):
        self.assertEqual(wt.human_age(42), "42s")
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
                    {"name": "a", "path": "/r.wt/a", "mounted": True, "branch": "a", "dirty_files": 2, "busy": True},
                    {"name": "b", "path": "/r.wt/b", "mounted": False},
                ],
            },
        )
        self.assertIn("dirty(2)", out)
        self.assertIn("busy", out)
        self.assertIn("UNMOUNTED", out)
        self.assertNotIn("identical", out)

    def test_render_list_sizes(self):
        row = {"name": "a", "path": "/r.wt/a", "mounted": True, "branch": "a", "dirty_files": 0, "busy": False}
        out = wt.render("list", {"repo": "/r", "worktrees": [{**row, "disk_bytes": 2 * 1024**3, "identical_bytes": 512 * 1024**2}]})
        self.assertIn("2.0G", out)
        self.assertIn("(512.0M identical to base)", out)

    def status_result(self, **overrides):
        result = {
            "repo": "/r",
            "base_ref": "origin/main",
            "warm": ["just pp"],
            "disk_free_bytes": 50 * 1024**3,
            "caches": [{"path": "/store", "bytes": 5 * 1024**3}],
            "base": {
                "path": "/r.wt/.base",
                "age": "1.0d",
                "commit": "c1b7927ae59abcdef",
                "unique_bytes": 3 * 1024**3,
                "shared_bytes": 6 * 1024**3,
                "warm_seconds": 840.0,
            },
            "worktrees": 2,
            "savings": {"wt_bytes": 6 * 1024**3, "git_bytes": 8 * 1024**3, "saved_bytes": 2 * 1024**3},
        }
        result.update(overrides)
        return result

    def test_render_status_savings(self):
        out = wt.render("status", self.status_result())
        self.assertIn("3.0G on disk, plus 6.0G hardlinked", out)
        self.assertIn("14m per run", out)
        self.assertIn("worktrees:   2\nsavings:     ~2.0G saved vs `git worktree add`", out)
        self.assertIn("cache:       /store 5.0G", out)

    def test_render_status_untimed_warm_and_net_cost(self):
        out = wt.render(
            "status",
            self.status_result(
                worktrees=0, savings={"wt_bytes": 4 * 1024**3, "git_bytes": 3 * 1024**3, "saved_bytes": -(1024**3)}
            )
            | {"base": {**self.status_result()["base"], "warm_seconds": None}},
        )
        self.assertIn("not timed yet", out)
        self.assertIn("~1.0G more vs", out)

    def test_render_status_without_base(self):
        out = wt.render("status", self.status_result(base=None, worktrees=0, savings=None, caches=[]))
        self.assertIn("none (run `wt base-init`)", out)
        self.assertIn("disk free", out)

    def test_guide_without_repo_uses_placeholders(self):
        text = wt.guide_text(None)
        self.assertIn("<repo>.wt", text)
        self.assertIn("wt config", text)

    def test_guide_with_repo_uses_real_paths_and_no_warm_listing(self):
        repo = wt.Repo(root=Path("/w/x"), base_ref="origin/main", warm=["just pp", "turbo run typecheck"])
        text = wt.guide_text(repo)
        self.assertIn("/w/x.wt/<branch>", text)
        self.assertNotIn("just pp", text)
        self.assertIn("uncommitted", text)
        self.assertNotIn("git push", text)


class ConfigKeys(unittest.TestCase):
    def test_loose_spelling_and_multi_flag(self):
        self.assertEqual(wt.config_key("warm"), ("wt.warm", True))
        self.assertEqual(wt.config_key("wt.CachePath"), ("wt.cachePath", True))
        self.assertEqual(wt.config_key("baseref"), ("wt.baseRef", False))
        self.assertEqual(wt.config_key("stateDir"), ("wt.stateDir", False))

    def test_unknown_key(self):
        with self.assertRaises(wt.WtError):
            wt.config_key("branchPrefix")


if __name__ == "__main__":
    unittest.main()
