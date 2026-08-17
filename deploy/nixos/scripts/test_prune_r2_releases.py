import datetime
import unittest

from prune_r2_releases import compute_prune_plan, sha256s_referenced

NOW = datetime.datetime(2026, 8, 17, tzinfo=datetime.timezone.utc)


def days_ago(n):
    return NOW - datetime.timedelta(days=n)


class Sha256sReferencedTests(unittest.TestCase):
    def test_finds_nested_hashes(self):
        manifest = {
            "images": {
                "choices": {
                    "coding-harnesses": {
                        "options": {
                            "claude-code": {"sha256": "aaa"},
                            "codex": {"sha256": "bbb"},
                        }
                    }
                },
                "required": {"server": {"sha256": "ccc"}},
            },
            "osImages": {"nixos": {"delivery": {"artifact": {"sha256": "ddd"}}}},
        }
        self.assertEqual(sha256s_referenced(manifest), {"aaa", "bbb", "ccc", "ddd"})

    def test_walks_lists(self):
        manifest = {"items": [{"sha256": "aaa"}, {"sha256": "bbb"}]}
        self.assertEqual(sha256s_referenced(manifest), {"aaa", "bbb"})

    def test_ignores_non_string_sha256(self):
        # a "sha256" key that isn't a hash string (defensive, shouldn't
        # happen in practice, but a null/number shouldn't be collected).
        manifest = {"sha256": None, "nested": {"sha256": 123}}
        self.assertEqual(sha256s_referenced(manifest), set())

    def test_empty_manifest(self):
        self.assertEqual(sha256s_referenced({}), set())


class ComputePrunePlanTests(unittest.TestCase):
    def test_live_referenced_kept_regardless_of_age(self):
        listing = [(days_ago(400), 100, "releases/abc.json")]
        keep, delete = compute_prune_plan(listing, {"abc"}, 90, NOW)
        self.assertEqual(keep, ["releases/abc.json"])
        self.assertEqual(delete, [])

    def test_old_and_unreferenced_is_deleted(self):
        listing = [(days_ago(400), 100, "releases/old.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, [])
        self.assertEqual(delete, ["releases/old.json"])

    def test_recent_and_unreferenced_is_kept(self):
        # Candidate builds that were never promoted still get a grace
        # window rather than being deleted the moment they're superseded.
        listing = [(days_ago(5), 100, "releases/candidate.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, ["releases/candidate.json"])
        self.assertEqual(delete, [])

    def test_exactly_at_retention_boundary_is_kept(self):
        listing = [(days_ago(90), 100, "releases/boundary.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, ["releases/boundary.json"])
        self.assertEqual(delete, [])

    def test_one_day_past_retention_boundary_is_deleted(self):
        listing = [(days_ago(91), 100, "releases/past.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, [])
        self.assertEqual(delete, ["releases/past.json"])

    def test_channel_pointers_never_pruned_even_if_old_and_unreferenced(self):
        listing = [(days_ago(1000), 100, "channels/stable.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, ["channels/stable.json"])
        self.assertEqual(delete, [])

    def test_channel_attestation_history_never_pruned(self):
        listing = [(days_ago(1000), 100, "attestations/channels/nightly/1.sigstore.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, ["attestations/channels/nightly/1.sigstore.json"])
        self.assertEqual(delete, [])

    def test_revocations_never_pruned(self):
        listing = [(days_ago(1000), 100, "revocations/releases.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, ["revocations/releases.json"])
        self.assertEqual(delete, [])

    def test_unknown_prefix_left_alone(self):
        # Conservative default: never delete something outside the
        # documented schema, even if it's old.
        listing = [(days_ago(1000), 100, "some-future-prefix/thing.json")]
        keep, delete = compute_prune_plan(listing, set(), 90, NOW)
        self.assertEqual(keep, ["some-future-prefix/thing.json"])
        self.assertEqual(delete, [])

    def test_hash_extracted_from_multi_dot_filename(self):
        # attestations/releases/<hash>.sigstore.json -- basename split on
        # the FIRST dot must still recover the bare hash.
        listing = [(days_ago(400), 100, "attestations/releases/abc.sigstore.json")]
        keep, delete = compute_prune_plan(listing, {"abc"}, 90, NOW)
        self.assertEqual(keep, ["attestations/releases/abc.sigstore.json"])
        self.assertEqual(delete, [])

    def test_mixed_batch(self):
        listing = [
            (days_ago(400), 100, "releases/live-old.json"),      # kept: referenced
            (days_ago(5), 100, "releases/candidate.json"),        # kept: recent
            (days_ago(400), 100, "releases/dead.json"),           # deleted
            (days_ago(1000), 100, "channels/nightly.json"),       # kept: never-prune
        ]
        keep, delete = compute_prune_plan(listing, {"live-old"}, 90, NOW)
        self.assertEqual(
            set(keep), {"releases/live-old.json", "releases/candidate.json", "channels/nightly.json"}
        )
        self.assertEqual(delete, ["releases/dead.json"])


if __name__ == "__main__":
    unittest.main()
