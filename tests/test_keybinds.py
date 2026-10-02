"""Rebindable controls: pure logic, the real Input module with remapped keys, and server persistence."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game, new_sim  # noqa: E402

KB = "ReplicatedStorage/Shared/Keybinds"
INPUT = "StarterPlayer/StarterPlayerScripts/IronClashClient/Input"


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


def to_py(binds, K):
    return {a.id: lua_list(binds[a.id]) for a in lua_list(K.ACTIONS)}


class KeybindLogic(unittest.TestCase):
    def setUp(self):
        self.g = Game()
        self.K = self.g.module(KB)

    def lua_table(self, d):
        lua = self.g.lua
        t = lua.table()
        for action, keys in d.items():
            arr = lua.table()
            for i, k in enumerate(keys, start=1):
                arr[i] = k
            t[action] = arr
        return t

    def test_defaults_are_valid_and_unique(self):
        d = to_py(self.K.defaults(), self.K)
        seen = {}
        for action, keys in d.items():
            self.assertGreaterEqual(len([k for k in keys if k]), 1, action)
            for k in keys:
                if k:
                    self.assertTrue(self.K.isBindable(k), k)
                    self.assertNotIn(k, seen, f"{k} bound to both {seen.get(k)} and {action}")
                    seen[k] = action

    def test_defaults_match_original_controls(self):
        d = to_py(self.K.defaults(), self.K)
        self.assertEqual([d[a][0] for a in ("b1", "b2", "b3", "b4")], ["U", "I", "J", "K"])
        self.assertEqual((d["throw"][0], d["twin"][0]), ("L", "O"))
        self.assertEqual((d["left"][0], d["right"][0], d["up"][0], d["down"][0]), ("A", "D", "W", "S"))
        self.assertIn("Space", d["up"])

    def test_sanitize_is_idempotent(self):
        once = self.K.sanitize(self.K.defaults())
        twice = self.K.sanitize(once)
        self.assertEqual(to_py(once, self.K), to_py(twice, self.K))

    def test_sanitize_rejects_junk(self):
        K = self.K
        self.assertEqual(to_py(K.sanitize(None), K), to_py(K.defaults(), K))
        self.assertEqual(to_py(K.sanitize("hello"), K), to_py(K.defaults(), K))
        bad = self.lua_table({"b1": ["NotAKey", "Escape", "", "X" * 40], "b2": ["I"]})
        out = to_py(K.sanitize(bad), K)
        self.assertNotIn("NotAKey", out["b1"])
        self.assertNotIn("Escape", out["b1"])
        self.assertTrue(any(out["b1"]), "an emptied action falls back to its default")
        self.assertEqual(out["b2"][0], "I")

    def test_sanitize_removes_duplicate_keys(self):
        K = self.K
        dup = to_py(K.defaults(), K)
        dup["b2"][0] = "U"  # same key as b1
        out = to_py(K.sanitize(self.lua_table(dup)), K)
        owners = [a for a, keys in out.items() if "U" in keys]
        self.assertEqual(owners, ["b1"])
        self.assertTrue(any(out["b2"]))

    def test_assign_replaces_and_swaps(self):
        K = self.K
        base = K.defaults()
        new, swapped, ok, _ = K.assign(base, "b1", 1, "F")
        d = to_py(new, K)
        self.assertTrue(ok)
        self.assertIsNone(swapped)
        self.assertEqual(d["b1"][0], "F")
        self.assertFalse(any("U" in v for v in d.values()), "old key is released")
        # taking a key owned by another action swaps the two
        new2, swapped2, ok2, _ = K.assign(base, "b1", 1, "I")
        d2 = to_py(new2, K)
        self.assertTrue(ok2)
        self.assertEqual(swapped2, "b2")
        self.assertEqual((d2["b1"][0], d2["b2"][0]), ("I", "U"))

    def test_assign_never_orphans_an_action(self):
        K = self.K
        base = K.defaults()
        # slot 2 of b1 is empty; taking b2's only keyboard key into it would leave b2 with just the pad key: allowed
        new, swapped, ok, _ = K.assign(base, "b1", 2, "I")
        d = to_py(new, K)
        self.assertTrue(ok)
        self.assertTrue(any(d["b2"]))
        # sole key of an action cannot be stolen into an empty slot if it would leave the action empty
        sole = to_py(base, K)
        sole["b2"] = ["I", "", "", ""]
        _, _, ok2, why = K.assign(self.lua_table(sole), "b1", 2, "I")
        self.assertFalse(ok2)
        self.assertIn("only key", why)

    def test_reserved_and_unknown_keys_refused(self):
        K = self.K
        for key in ("Escape", "Slash", "NotAKey", ""):
            _, _, ok, _ = K.assign(K.defaults(), "b1", 1, key)
            self.assertFalse(ok, key)

    def test_clear_keeps_at_least_one_key(self):
        K = self.K
        base = K.defaults()
        _, ok = K.clear(base, "b1", 4)  # pad X
        self.assertTrue(ok)
        only = to_py(base, K)
        only["b1"] = ["U", "", "", ""]
        _, ok2 = K.clear(self.lua_table(only), "b1", 1)
        self.assertFalse(ok2)

    def test_display_helpers(self):
        K = self.K
        d = K.defaults()
        self.assertEqual(K.pretty("Space"), "SPACE")
        self.assertEqual(K.pretty(""), "-")
        self.assertEqual(K.keysText(d, "up", 2), "W / UP")
        self.assertEqual(K.notation("1, 2, 4", d), "U, I, K")
        self.assertEqual(K.notation("d/f+2", d), "d/f+I")


def session(latency=0.0):
    g, sim = new_sim(latency)
    P = sim.addPlayer("Tester", sim.fightControl)
    sim.fire(P, "Ready")
    sim.fire(P, "Queue", "practice", "Stand")
    sim.run(0.5)
    P.client.attachInput(P.client, g.module(INPUT))
    sim.run(0.3)
    return g, sim, P


class InputRemap(unittest.TestCase):
    def remap(self, g, P, changes):
        K = g.module(KB)
        binds = K.defaults()
        for action, slot, key in changes:
            binds, _, ok, why = K.assign(binds, action, slot, key)
            assert ok, why
        P.client.input.setBindings(P.client.input, binds)
        return binds

    def approach(self, sim, key="D"):
        sim.keyDown(key)
        sim.run(1.6)
        sim.keyUp(key)
        sim.run(0.5)

    def test_default_keys_still_attack(self):
        g, sim, P = session()
        self.approach(sim)
        sim.tap("U", 0.03)
        sim.run(0.5)
        self.assertEqual([x.id for x in lua_list_values(P.client.started)], ["1"])

    def test_rebound_attack_key_works_and_old_key_does_not(self):
        g, sim, P = session()
        self.remap(g, P, [("b1", 1, "F")])
        self.approach(sim)
        sim.tap("U", 0.03)
        sim.run(0.4)
        self.assertEqual(len(lua_list_values(P.client.started)), 0, "old key must no longer attack")
        sim.tap("F", 0.03)
        sim.run(0.4)
        self.assertEqual([x.id for x in lua_list_values(P.client.started)], ["1"])

    def test_string_with_rebound_keys(self):
        g, sim, P = session(0.06)
        self.remap(g, P, [("b1", 1, "F"), ("b2", 1, "G"), ("b4", 1, "H")])
        self.approach(sim)
        start = len(sim.fx)
        for key in ("F", "G", "H"):
            sim.tap(key, 0.03)
            sim.run(0.16)
        sim.run(1.2)
        moves = [sim.fx[i].data.move for i in range(start + 1, len(sim.fx) + 1) if sim.fx[i].kind == "Hit"]
        self.assertEqual(moves, ["1", "1_2", "1_2_4"])

    def test_rebound_movement_keys(self):
        g, sim, P = session()
        self.remap(g, P, [("right", 1, "G")])
        S = P.client.S
        x0 = S.motor.pos.X
        sim.keyDown("D")  # old key: nothing (D swapped away from `right`)
        sim.run(0.5)
        sim.keyUp("D")
        d_moved = abs(S.motor.pos.X - x0)
        x1 = S.motor.pos.X
        sim.keyDown("G")
        sim.run(0.8)
        sim.keyUp("G")
        g_moved = abs(S.motor.pos.X - x1)
        self.assertGreater(g_moved, 1.5)
        self.assertLess(d_moved, 0.3)

    def test_swapped_keys_attack_correctly(self):
        g, sim, P = session()
        self.remap(g, P, [("b1", 1, "I")])  # swaps 1 and 2: I = jab, U = straight
        self.approach(sim)
        sim.tap("I", 0.03)
        sim.run(0.6)
        sim.tap("U", 0.03)
        sim.run(0.6)
        self.assertEqual([x.id for x in lua_list_values(P.client.started)], ["1", "2"])

    def test_throw_and_twin_keys_rebind(self):
        g, sim, P = session()
        self.remap(g, P, [("throw", 1, "Z")])
        self.approach(sim)
        sim.tap("Z", 0.03)
        sim.run(0.5)
        self.assertEqual([x.id for x in lua_list_values(P.client.started)], ["throw"])

    def test_capture_swallows_the_key(self):
        g, sim, P = session()
        got = []
        P.client.input.beginCapture(P.client.input, lambda name: got.append(name))
        self.approach(sim, "D")  # movement keys are captured too, not walked
        self.assertEqual(got, ["D"])
        sim.tap("U", 0.03)  # capture already consumed: this one is a real attack
        sim.run(0.4)
        self.assertEqual(got, ["D"])

    def test_capture_does_not_attack(self):
        g, sim, P = session()
        self.approach(sim)
        got = []
        P.client.input.beginCapture(P.client.input, lambda name: got.append(name))
        sim.tap("U", 0.03)
        sim.run(0.4)
        self.assertEqual(got, ["U"])
        self.assertEqual(len(lua_list_values(P.client.started)), 0)

    def test_cancel_capture_reports_nil(self):
        g, sim, P = session()
        got = []
        P.client.input.beginCapture(P.client.input, lambda name: got.append(name))
        P.client.input.cancelCapture(P.client.input)
        self.assertEqual(got, [None])


def lua_list_values(t):
    # lupa tables used as sparse arrays: iterate in key order
    return [t[k] for k in sorted(t.keys())]


class ServerPersistence(unittest.TestCase):
    def test_keys_command_is_sanitized_and_saved(self):
        g, sim = new_sim(0.0)
        P = sim.addPlayer("Tester", sim.fightControl)
        sim.fire(P, "Ready")
        K = g.module(KB)
        binds = K.defaults()
        binds, _, ok, _ = K.assign(binds, "b1", 1, "F")
        sim.fire(P, "Keys", binds)
        saved = sim.lastKeys
        self.assertIsNotNone(saved)
        self.assertEqual(saved["b1"][1], "F")

    def test_garbage_is_harmless(self):
        g, sim = new_sim(0.0)
        P = sim.addPlayer("Tester", sim.fightControl)
        sim.fire(P, "Ready")
        lua = g.lua
        for junk in ("x", 5, None, True, lua.table(), lua.eval("{b1 = 'U', b2 = {1,2,3}, left = {{}}}")):
            sim.run(0.3)
            sim.fire(P, "Keys", junk)
        saved = sim.lastKeys
        K = g.module(KB)
        if saved is not None:
            for a in lua_list(K.ACTIONS):
                self.assertTrue(any(saved[a.id][i] for i in range(1, 5)), a.id)
        self.assertEqual(list(g.env.__warnings.values()) if g.env.__warnings else [], [])

    def test_saved_keys_are_sent_on_ready(self):
        g, sim = new_sim(0.0)
        K = g.module(KB)
        binds, _, ok, _ = K.assign(K.defaults(), "taunt", 1, "G")
        sim.savedKeys = binds
        P = sim.addPlayer("Tester", sim.fightControl)
        sim.fire(P, "Ready")
        sim.run(0.2)
        msgs = [m for m in sim.serverMsgs.values() if m.args[1] == "Keys"]
        self.assertTrue(msgs, "server should push saved bindings")
        self.assertEqual(msgs[-1].args[2]["taunt"][1], "G")


if __name__ == "__main__":
    unittest.main()
