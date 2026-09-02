import os
import tempfile
import unittest
from pathlib import Path

from scripts import s2_local


DEFAULT_EXAMPLE = Path(
    "/private/tmp/claude-501/"
    "-Users-jordan-Desktop-Projects-johomax-johomax-ctf/"
    "03d51cf8-6269-4db4-b491-8b718594822a/"
    "scratchpad/wstest12"
)
TEAMS = [
    "red", "blue", "green", "yellow", "black", "silver", "ivory",
    "pink", "umber", "rust", "orange", "plum", "lime", "navy",
    "azure", "peach",
] * 2


class ExampleLogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.log_dir = Path(os.environ.get("S2_EXAMPLE_LOG_DIR", DEFAULT_EXAMPLE))
        if not (cls.log_dir / "server.log").is_file():
            raise unittest.SkipTest(f"example logs not found: {cls.log_dir}")
        assign = {str(seat): "nim" for seat in range(s2_local.SEATS)}
        bot_texts = {
            seat: (cls.log_dir / f"bot_{seat}.log").read_text(
                encoding="utf-8", errors="replace")
            for seat in range(s2_local.SEATS)
        }
        cls.summary = s2_local.parse_summary(
            (cls.log_dir / "server.log").read_text(
                encoding="utf-8", errors="replace"),
            bot_texts, assign, TEAMS, seed=1106700625, stop_reason="timeout")

    def test_all_modules_and_calls_were_accepted(self):
        self.assertEqual(self.summary["module_ready_lines"], 192)
        self.assertEqual(self.summary["call_accepted_seats"], list(range(32)))
        self.assertEqual(self.summary["module_rejection_seats"], [])

    def test_reconnect_storm_is_visible(self):
        self.assertEqual(self.summary["reconnected_seats"], list(range(32)))
        self.assertEqual(self.summary["reconnect_events"], 653)

    def test_window_has_no_combat_result(self):
        self.assertEqual(self.summary["kill_lines"], 0)
        self.assertEqual(self.summary["per_bot"]["nim"]["kills"], 0)
        self.assertIsNone(self.summary["winner_colour"])
        self.assertIsNone(self.summary["winner_bot"])
        self.assertFalse(self.summary["completed"])


class ParserUnitTests(unittest.TestCase):
    def test_positive_winner_kill_tick_and_bot_markers(self):
        assign = {
            str(seat): ("A" if seat % 16 == 0 else "B")
            for seat in range(32)
        }
        bots = {
            0: "[s2] module ready name=x\n[s2] call accepted phase=x\n"
               "season2 reconnect: test\n",
            1: '[s2] status {"kind":"module_rejected"}\n',
        }
        summary = s2_local.parse_summary(
            "game started: players=32\nred killed by blue\nred win\n"
            "Frame pacing: 123 playing frames\n",
            bots, assign, TEAMS, seed=7, stop_reason="winner")
        self.assertEqual(summary["winner_bot"], "A")
        self.assertEqual(summary["per_bot"]["A"]["deaths"], 1)
        self.assertEqual(summary["per_bot"]["B"]["kills"], 1)
        self.assertEqual(summary["game_ticks"], 123)
        self.assertEqual(summary["team_kill_lines"], 0)
        self.assertEqual(summary["call_accepted_seats"], [0])
        self.assertEqual(summary["module_rejection_seats"], [1])
        self.assertEqual(summary["reconnected_seats"], [0])

    def test_same_colour_kill_is_counted_as_partner_kill(self):
        assign = {str(seat): "A" for seat in range(32)}
        summary = s2_local.parse_summary(
            "game started: players=32\nred killed by red\nred win\n",
            {}, assign, TEAMS)
        self.assertEqual(summary["team_kill_lines"], 1)
        self.assertEqual(summary["per_bot"]["A"]["team_kills"], 1)

    def test_hardening_ticks_are_rebased_to_game_start(self):
        assign = {str(seat): "A" for seat in range(32)}
        summary = s2_local.parse_summary(
            "FIRST_LIGHT_MOVEMENT tick=700 seats=32\n"
            "game started: players=32\n"
            "FIRST_LIGHT_MOVEMENT tick=791 seats=32\n"
            "FIRST_LIGHT_MOVEMENT tick=792 seats=32\n"
            "FIRST_LIGHT_MOVEMENT tick=793 seats=32\nred win\n",
            {}, assign, TEAMS)
        self.assertEqual(summary["game_ticks"], 3)

    def test_seed_rotation_keeps_duos_together(self):
        specs = [
            s2_local.BotSpec("A", "A", "executable", "/A", 1),
            s2_local.BotSpec("B:3", "B", "executable", "/B", 3),
        ]
        first = s2_local.assignment_for_seed(specs, 100)
        second = s2_local.assignment_for_seed(specs, 101)
        for duo in range(16):
            self.assertEqual(first[str(duo)], first[str(duo + 16)])
            self.assertEqual(second[str(duo)], second[str(duo + 16)])
        self.assertNotEqual(first, second)

    def test_bot_env_file_is_scoped_by_label(self):
        specs = [
            s2_local.BotSpec("A", "A", "executable", "/A", 1),
            s2_local.BotSpec("B", "B", "executable", "/B", 1),
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "recipe.env"
            path.write_text(
                "# recipe\nS2_OPENING_CALL={\"plays\":[]}\nS2_RECALLS=[]\n",
                encoding="utf-8")
            parsed = s2_local.parse_bot_env_files(
                [f"A={path}"], specs)
        self.assertEqual(parsed, {"A": {
            "S2_OPENING_CALL": '{"plays":[]}',
            "S2_RECALLS": "[]",
        }})
        self.assertNotIn("B", parsed)


class PoolUnitTests(unittest.TestCase):
    def test_pool_uses_episode_bootstrap_and_seat_rates(self):
        rows = []
        for seed, winner in ((1, "A"), (2, "B")):
            per_bot = {
                "A": {
                    "duos": 8, "wins": int(winner == "A"), "kills": 8,
                    "accepted_call_seats": list(range(16)),
                    "reconnected_seats": [],
                },
                "B": {
                    "duos": 8, "wins": int(winner == "B"), "kills": 4,
                    "accepted_call_seats": list(range(16, 24)),
                    "reconnected_seats": list(range(16, 20)),
                },
            }
            rows.append((Path(f"seed-{seed}/summary.json"), {
                "seed": seed, "completed": True, "per_bot": per_bot,
            }))
        report = s2_local.pool_summaries(rows)
        self.assertEqual(report["episodes_pooled"], 2)
        self.assertEqual(report["per_bot"]["A"]["win_share"], 0.5)
        self.assertEqual(report["per_bot"]["A"]["mean_kills_per_duo"], 1.0)
        self.assertEqual(report["per_bot"]["A"]["accepted_call_rate"], 1.0)
        self.assertEqual(report["per_bot"]["B"]["accepted_call_rate"], 0.5)
        self.assertEqual(report["per_bot"]["B"]["reconnect_rate"], 0.25)


if __name__ == "__main__":
    unittest.main()
