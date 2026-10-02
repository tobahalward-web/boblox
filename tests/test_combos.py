"""Combo system tests.

Run:  python3 -m unittest discover -s tests -v

* Frame-data invariants (every string is a true combo, every move has an animation).
* End-to-end replays: the real MatchService / Motor / Combat / Input / FightControl running against a
  fake network with latency. Every showcase combo in Moves.Combos is typed on the real keyboard module
  with human-like gaps and must land exactly the hits it advertises.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game, new_sim  # noqa: E402

INPUT = "StarterPlayer/StarterPlayerScripts/IronClashClient/Input"
KEYS = {"1": "U", "2": "I", "3": "J", "4": "K"}


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


class FrameData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()
        cls.Moves = cls.g.module("ReplicatedStorage/Shared/Moves")
        cls.Poses = cls.g.module("ReplicatedStorage/Shared/Poses")

    def moves(self):
        return {k: v for k, v in self.Moves.List.items()}

    def test_every_move_has_an_animation(self):
        clips = self.Poses.Clips
        missing = [k for k in self.moves() if clips[k] is None]
        self.assertEqual(missing, [], f"moves without a pose clip: {missing}")

    def test_every_move_is_in_the_move_list(self):
        order = set(lua_list(self.Moves.Order))
        missing = [k for k in self.moves() if k not in order]
        self.assertEqual(missing, [])

    def test_chain_targets_exist_and_windows_are_sane(self):
        for id_, m in self.moves().items():
            if m.chain is None:
                continue
            self.assertGreaterEqual(m.cancelAt, m.startup + m.active, f"{id_} cancels before its strike resolves")
            self.assertGreaterEqual(m.chainTo, m.cancelAt, f"{id_} chain window closes before it opens")
            self.assertLess(m.chainTo, m.total, f"{id_} chain window outlasts the move")
            for btn, nxt in m.chain.items():
                self.assertIsNotNone(self.Moves.List[nxt], f"{id_} chains into missing move {nxt}")

    def test_every_string_is_a_true_combo_on_hit(self):
        # latest possible press (chainTo) still connects before the opponent recovers (total + onHit)
        for id_, m in self.moves().items():
            if m.chain is None:
                continue
            for btn, nxt in m.chain.items():
                n = self.Moves.List[nxt]
                contact = m.chainTo + n.startup
                self.assertLess(contact, m.total + m.onHit, f"{id_} -> {nxt} can be escaped on hit")

    def test_combo_list_matches_moves(self):
        for c in lua_list(self.Moves.Combos):
            for step in lua_list(c.steps):
                self.assertIsNotNone(self.Moves.List[step], f"{c.name}: unknown step {step}")


def make_session(latency):
    g, sim = new_sim(latency)
    P = sim.addPlayer("Tester", sim.fightControl)
    sim.fire(P, "Ready")
    sim.fire(P, "Queue", "practice", "Stand")
    sim.run(0.5)
    Input = g.module(INPUT)
    P.client.attachInput(P.client, Input)
    sim.run(0.3)
    sim.keyDown("D")
    sim.run(1.6)
    sim.keyUp("D")
    sim.run(0.5)
    return g, sim, P


def hits_since(sim, start):
    out = []
    for i in range(start + 1, len(sim.fx) + 1):
        e = sim.fx[i]
        if e.kind == "Hit":
            out.append((e.data.move, e.data.kind, e.data.combo))
    return out


def press(sim, token):
    """Press one combo token on the keyboard: '1'..'4' or 'df1' / 'df2' (down-forward + button)."""
    if token.startswith("df"):
        sim.keyDown("S")
        sim.keyDown("D")
        sim.run(0.05)
        sim.tap(KEYS[token[2]], 0.03)
        sim.keyUp("S")
        sim.keyUp("D")
    else:
        sim.tap(KEYS[token], 0.03)


def run_combo(combo, latency, gap, react):
    g, sim, P = make_session(latency)
    start = len(sim.fx)
    presses = lua_list(combo.presses)
    for tok in presses:
        if tok == "@juggle":
            # wait until the launch lands, then react like a human before pressing again
            for _ in range(180):
                sim.run(1 / 60)
                if any(e.data.kind == "launch" for e in [sim.fx[i] for i in range(start + 1, len(sim.fx) + 1)] if e.kind == "Hit"):
                    break
            sim.run(react)
            continue
        press(sim, tok)
        sim.run(gap)
    sim.run(1.6)
    return [h[0] for h in hits_since(sim, start)], hits_since(sim, start)


class ComboReplay(unittest.TestCase):
    def _check(self, latency, gaps, reacts):
        g = Game()
        combos = lua_list(g.module("ReplicatedStorage/Shared/Moves").Combos)
        failures = []
        for combo in combos:
            expected = lua_list(combo.steps)
            has_juggle = "@juggle" in lua_list(combo.presses)
            for gap in gaps:
                for react in (reacts if has_juggle else (0.0,)):
                    got, detail = run_combo(combo, latency, gap, react)
                    if got != expected:
                        failures.append(f"{combo.name} lat={latency} gap={gap} react={react}: got {got}, want {expected}")
        self.assertEqual(failures, [], "\n" + "\n".join(failures))

    def test_low_latency(self):
        self._check(0.0, (0.10, 0.16, 0.22), (0.25, 0.45))

    def test_typical_latency(self):
        self._check(0.06, (0.10, 0.16, 0.22), (0.25, 0.45))

    def test_high_latency(self):
        self._check(0.15, (0.12, 0.18), (0.30, 0.45))

    def test_combo_counter_counts_every_hit(self):
        g, sim, P = make_session(0.06)
        start = len(sim.fx)
        for tok in ("1", "2", "4"):
            press(sim, tok)
            sim.run(0.16)
        sim.run(1.2)
        hits = hits_since(sim, start)
        self.assertEqual([h[2] for h in hits], [1, 2, 3])

    def test_no_server_rejects_during_normal_strings(self):
        g, sim, P = make_session(0.08)
        for tok in ("1", "2", "4"):
            press(sim, tok)
            sim.run(0.14)
        sim.run(1.2)
        self.assertEqual(len(sim.rejects), 0, [(r.id, r.why) for r in sim.rejects.values()])


class Fuzz(unittest.TestCase):
    """Random keyboard mashing through full CPU matches must never raise a runtime error."""

    def test_cpu_match_with_random_input(self):
        import random

        rnd = random.Random(7)
        keys = ["A", "D", "W", "S", "U", "I", "J", "K", "L", "O", "Q", "E", "T"]
        for seed_level in (1, 3, 5):
            g, sim = new_sim(0.05)
            P = sim.addPlayer("Fuzzer", sim.fightControl)
            sim.fire(P, "Ready")
            sim.fire(P, "Queue", "fight")
            sim.run(0.2)
            P.client.attachInput(P.client, g.module(INPUT))
            held = set()
            for step in range(60 * 70):
                if step % 4 == 0:
                    k = rnd.choice(keys)
                    if k in held and rnd.random() < 0.6:
                        sim.keyUp(k)
                        held.discard(k)
                    elif rnd.random() < 0.5:
                        sim.keyDown(k)
                        held.add(k)
                    else:
                        sim.keyDown(k)
                        sim.keyUp(k)
                sim.step(1 / 60)
            warns = [w for w in lua_list(g.env.__warnings)] if g.env.__warnings else []
            self.assertEqual(warns, [], f"runtime warnings: {warns}")


if __name__ == "__main__":
    unittest.main()
