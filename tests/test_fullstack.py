"""Full-stack runs: the real IronClashClient script + real server + real fighter models (headless).

These catch runtime errors anywhere in the client (UI, camera, animator, effects, themes) and the server
while an actual match is played with keyboard input.
"""
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import new_sim  # noqa: E402


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


def warnings(g):
    w = g.env.__warnings
    return [w[i] for i in sorted(w.keys())] if w else []


def boot(latency=0.05):
    g, sim = new_sim(latency, real_fighters=True)
    P = sim.addRealPlayer()
    sim.run(0.5)
    return g, sim, P


class FullStack(unittest.TestCase):
    def test_boot_reaches_the_menu(self):
        g, sim, P = boot()
        sim.run(1.0)
        kinds = [m.args[1] for m in sim.serverMsgs.values()]
        self.assertIn("Menu", kinds)
        self.assertEqual(warnings(g), [])

    def test_practice_string_with_real_client(self):
        g, sim, P = boot(0.05)
        sim.fire(P, "Queue", "practice", "Stand")
        sim.run(1.0)
        self.assertIn("Setup", [m.args[1] for m in sim.serverMsgs.values()])
        sim.keyDown("D")
        sim.run(1.8)
        sim.keyUp("D")
        sim.run(0.4)
        start = len(sim.fx)
        for key in ("U", "I", "K"):
            sim.tap(key, 0.03)
            sim.run(0.16)
        sim.run(1.5)
        moves = [sim.fx[i].data.move for i in range(start + 1, len(sim.fx) + 1) if sim.fx[i].kind == "Hit"]
        self.assertEqual(moves, ["1", "1_2", "1_2_4"])
        self.assertEqual(warnings(g), [])

    def test_juggle_with_real_client(self):
        g, sim, P = boot(0.05)
        sim.fire(P, "Queue", "practice", "Stand")
        sim.run(1.0)
        sim.keyDown("D")
        sim.run(1.8)
        sim.keyUp("D")
        sim.run(0.4)
        start = len(sim.fx)
        sim.keyDown("S")
        sim.keyDown("D")
        sim.run(0.05)
        sim.tap("I", 0.03)
        sim.keyUp("S")
        sim.keyUp("D")
        for _ in range(180):
            sim.run(1 / 60)
            if any(sim.fx[i].kind == "Hit" and sim.fx[i].data.kind == "launch" for i in range(start + 1, len(sim.fx) + 1)):
                break
        sim.run(0.4)
        for key in ("U", "I", "K"):
            sim.tap(key, 0.03)
            sim.run(0.15)
        sim.run(1.5)
        moves = [sim.fx[i].data.move for i in range(start + 1, len(sim.fx) + 1) if sim.fx[i].kind == "Hit"]
        self.assertEqual(moves, ["df2", "1", "1_2", "1_2_4"])
        self.assertEqual(warnings(g), [])

    def test_cpu_match_with_random_mashing(self):
        rnd = random.Random(11)
        keys = ["A", "D", "W", "S", "U", "I", "J", "K", "L", "O", "Q", "E", "T", "M"]
        g, sim, P = boot(0.05)
        sim.fire(P, "Queue", "fight")
        held = set()
        for step in range(60 * 75):
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
        phases = [m.args[2] for m in sim.serverMsgs.values() if m.args[1] == "Phase"]
        self.assertIn("Fight", phases)
        self.assertEqual(warnings(g), [])


if __name__ == "__main__":
    unittest.main()
