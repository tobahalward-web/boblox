"""Smoke tests for the client UI: every client module must load and construct without errors.

A typo in UI code would otherwise only show up as a black screen in Studio, so this instantiates the
real Menu / HUD / Controls / Preview / Touch / Animator against the headless shim.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import Game  # noqa: E402

CLIENT = "StarterPlayer/StarterPlayerScripts/IronClashClient/"
KB = "ReplicatedStorage/Shared/Keybinds"


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


class ClientLoad(unittest.TestCase):
    def setUp(self):
        self.g = Game()
        self.g.shim.service("Players")  # make sure LocalPlayer exists

    def mod(self, name):
        return self.g.module(CLIENT + name)

    def test_ui_helpers(self):
        UI = self.mod("UI")
        b, label = UI.button(self.g.lua.table_from({"Text": "X", "Size": self.g.env.UDim2.new(1, 0, 1, 0)}))
        self.assertIsNotNone(b)

    def test_menu_constructs(self):
        Menu = self.mod("Menu")
        m = Menu.new()
        self.assertIsNotNone(m.buttons)
        m.show(m)
        m.setStatus(m, "hello", False)

    def test_hud_constructs_and_rebuilds_for_new_bindings(self):
        HUD = self.mod("HUD")
        K = self.g.module(KB)
        hud = HUD.new()
        binds, _, ok, _ = K.assign(K.defaults(), "b1", 1, "F")
        self.assertTrue(ok)
        hud.setBinds(hud, binds)
        self.assertIn("F", hud.hint.Text)
        self.assertIn("F", hud.breakPrompt.Text)
        hud.toggleMoves(hud, True)
        self.assertTrue(hud.moveList.Visible)
        hud.setBinds(hud, K.defaults())
        self.assertTrue(hud.moveList.Visible, "move list stays open across a rebuild")

    def test_controls_screen_rebinds_through_real_input(self):
        Input = self.mod("Input")
        Controls = self.mod("Controls")
        K = self.g.module(KB)
        input_ = Input.new(K.defaults())
        changes = []
        c = Controls.new(input_, K.defaults(), lambda b: changes.append(b))
        c.show(c)
        self.assertTrue(c.isOpen(c))
        # click KEY 1 of button 1, then press F
        c.startCapture(c, "b1", 1)
        self.g.env.game.GetService(self.g.env.game, "UserInputService")._props.InputBegan.Fire(
            self.g.env.game.GetService(self.g.env.game, "UserInputService")._props.InputBegan,
            self.g.lua.table_from({"KeyCode": self.g.env.Enum.KeyCode.F}), False,
        )
        self.assertEqual(len(changes), 1)
        self.assertEqual(changes[0]["b1"][1], "F")
        # swap: give button 2's key to button 1
        c.startCapture(c, "b1", 1)
        UIS = self.g.env.game.GetService(self.g.env.game, "UserInputService")
        UIS._props.InputBegan.Fire(UIS._props.InputBegan, self.g.lua.table_from({"KeyCode": self.g.env.Enum.KeyCode.I}), False)
        self.assertEqual(len(changes), 2)
        self.assertEqual((changes[1]["b1"][1], changes[1]["b2"][1]), ("I", "F"))
        c.hide(c)

    def test_controls_refuses_reserved_key(self):
        Input = self.mod("Input")
        Controls = self.mod("Controls")
        K = self.g.module(KB)
        input_ = Input.new(K.defaults())
        changes = []
        c = Controls.new(input_, K.defaults(), lambda b: changes.append(b))
        c.startCapture(c, "b1", 1)
        UIS = self.g.env.game.GetService(self.g.env.game, "UserInputService")
        UIS._props.InputBegan.Fire(UIS._props.InputBegan, self.g.lua.table_from({"KeyCode": self.g.env.Enum.KeyCode.Slash}), False)
        self.assertEqual(changes, [])
        self.assertIn("CAN'T", c.status.Text)

    def test_touch_constructs(self):
        Input = self.mod("Input")
        Touch = self.mod("Touch")
        t = Touch.new(Input.new())
        t.setVisible(t, True)

    def test_every_fighter_builds_and_previews(self):
        FM = self.g.module("ReplicatedStorage/Shared/FighterModels")
        Preview = self.mod("Preview")
        for f in lua_list(FM.ROSTER):
            for pal in (1, 2):
                model = FM.build(f.id, pal, f.name)
                self.assertGreater(len(lua_list(model.GetDescendants(model))), 20, f.id)
        gui = self.g.shim.Instance.new("Frame")
        for f in lua_list(FM.ROSTER):
            p = Preview.new(gui, f.id, 1, "full")
            p.pose(p, 1 / 60, True)


if __name__ == "__main__":
    unittest.main()
